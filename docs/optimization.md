# Optimizing SYCL programs for Intel® FPGA cards

Optimizing SYCL code for Intel FPGAs requires a combination of understanding the FPGA hardware, the SYCL programming model, and the specific compiler features provided by Intel. Here are some general guidelines to optimize Intel FPGA SYCL code.

Compared to OpenCL, the Intel® oneAPI DPC++ compiler has enhanced features to detect possible optimizations( vectorization, static coalescing, etc ...). Nonetheless, some rules need to be followed to make sure the compiler is able to apply these optimizations. 

!!! warning "Optimizing your design"
    As this course/workshop is only an introduction to the Intel® oneAPI for FPGA programming, we can't unfortunately provide all existing and possible optimizations. Many more optimizations can be found in the Intel official documentation.

## Loop optimization

Loop unrolling is an optimization technique that aims to increase parallelism and, consequently, the throughput of certain computational tasks, particularly when implemented in hardware environments such as FPGAs. 


1. **Pipelining Synergy**: Loop unrolling often goes hand in hand with pipelining in FPGAs. When loops are unrolled, each unrolled iteration can be pipelined, leading to even greater throughput enhancements.

2. **Resource Utilization**: While loop unrolling can significantly speed up operations, it also consumes more FPGA resources, like Logic Elements (LEs) and registers, because of the duplicated hardware. Hence, there's a trade-off between speed and resource utilization.

3. **Memory Access**: Unrolling loops that involve memory operations can lead to increased memory bandwidth utilization. In cases where memory bandwidth is a bottleneck, unrolling can provide substantial performance improvements.

4. **Latency & Throughput**: Loop unrolling doesn't necessarily reduce the latency of a single loop iteration (the time taken for one iteration to complete), but it can significantly improve the throughput (number of completed operations per unit time).


5. **Reduction in Control Logic**: Unrolling can reduce the overhead associated with the loop control logic, such as incrementing the loop counter and checking the loop termination condition.

    <figure markdown>
        ![](https://res.cloudinary.com/dxzx2bxch/image/upload/v1604459708/posts/X14770-loop-pipelining_v42eza.svg)
       <figcaption>[Loop Optimization in HLS](https://www.zzzdavid.tech/loop_opt/)</figcaption>
    </figure>

* Unrolling loops will help to reduce the Initialization Interval (II) as you can notice on the previous figure.

!!! tig "Increasing throughput with loop unrolling"
    === "How to unroll loops"
        * Unrolling loop can be done using the `#pragma unroll <N>`
        * `<N>` is the unroll factor
        * `#pragma unroll 1` : prevent a loop in your kernel from unrolling
        * `#pragma unroll` : let the offline compiler decide how to unroll the loop 
        ```cpp
        handler.single_task<class example>([=]() {
            #pragma unroll
                for (int i = 0; i < 10; i++) {
                    acc_data[i] += i;
                }
            #pragma unroll 1
            for (int k = 0; k < N; k++) {
                #pragma unroll 5
                for (int j = 0; j < N; j++) {
                    acc_data[j] = j + k;
                }
            }
        });
        ```

    === "Question"
        * Consider the following code that you can find at `oneAPI-samples/DirectProgramming/C++SYCL_FPGA/Tutorials/Features/loop_unroll`
        * Note that Intel did not consider data alignment which could impact performance
        * We included `#include <boost/align/aligned_allocator.hpp>` to create aligned std::vector
        * The following SYCL code has been already compiled for you, execute it on the FPGA nodes for several data input size and record the throughput and kernel time
        * What do you observe ?
        ```cpp linenums="1"
        --8<-- "./code/09-loop_unroll/src/loop_unroll.cpp"
        ```
    === "Solution"

        <div align="center">

        | Unroll factor   | kernel execution time (ms)   | Throughput (GFlops) |
        |:---------------:|:----------------------------:|:-------------------:|
        |       1         |             77               |        0.447        |
        |       2         |             58               |        0.591        |
        |       4         |             43               |        0.804        |
        |       8         |             40               |        0.857        |
        |       16        |             39               |        0.882        |

        </div>

        * Increasing the unroll factor improves throughput    
        * Nonetheless, unrolling large loops should be avoided as it would require a large amount of hardware
        !!! warning "Recording kernel time"
            * In this example, we have also seen how to record kernel time.
            * Using the property `property::queue::enable_profiling{}`` adds the requirement that the runtime must capture profiling information for the command groups that are submitted from the queue 
            * You can the capture  the start & end time using the following two commands:
                - `double start = e.get_profiling_info<info::event_profiling::command_start>();`
                - `double end = e.get_profiling_info<info::event_profiling::command_end>();`

!!! warning "Caution with nested loops"
    * Loop unrolling involves replicating the hardware of a loop body multiple times and reducing the trip count of a loop. Unroll loops to reduce or eliminate loop control overhead on the FPGA. 
    * Loop-unrolling can be used to eliminate nested-loop structures.
    * However avoid unrolling the outer-loop which will lead to **Resource Exhaustion** and dramatically increase offline compilation

## Loop coalescing

Utilize the `loop_coalesce` attribute to instruct the Intel® oneAPI DPC++/C++ Compiler to merge nested loops into one, preserving the loop's original functionality. By coalescing loops, you can minimize the kernel's area consumption by guiding the compiler to lessen the overhead associated with loop management.

!!! example "Coalesced two loops"
    === "Using the loop_coalesce attribute"
    ```cpp
    [[intel::loop_coalesce(2)]]
    for (int i = 0; i < N; i++)
       for (int j = 0; j < M; j++)
          sum[i][j] += i+j;
    ```
    === "Equivalent code"
    ```cpp
    int i = 0;
    int j = 0;
    while(i < N){
      sum[i][j] += i+j;
      j++;
      if (j == M){
        j = 0;
        i++;
      }
    }
    ```


## Ignore Loop-carried dependencies

The **ivdep** attribute in Intel's oneAPI (as well as in other Intel compiler tools) is used to give a hint to the compiler about the independence of iterations in a loop. This hint suggests that there are no loop-carried memory dependencies that the compiler needs to account for when attempting to vectorize or parallelize the loop.

When you use **ivdep**, you're essentially telling the compiler: "Trust me, I've reviewed the code, and the iterations of this loop do not have dependencies on each other. So, you can safely vectorize or parallelize this loop for better performance."

!!! example "ivdep attribute"
    ```cpp
    #pragma ivdep
    for (int i = 1; i < N; i++) {
        A[i] = A[i - 1] + B[i];
    }
    ```
    In the loop above, there appears to be a loop-carried dependency because each iteration of the loop seems to depend on the result of the previous iteration. However, if the programmer knows something about the data or the context in which the loop is used that the compiler might not be aware of, the ivdep pragma can be used to give the compiler the green light to vectorize the loop.

!!! warning "Caution"
    You should be very careful when using **ivdep**. Incorrectly using this pragma on a loop that does have dependencies can lead to unexpected results or undefined behavior. Always ensure that there are truly no dependencies in the loop before applying this hint.

## Memory Coalescing

## Local memory

## Task parallelism with Inter-Kernel Pipes
