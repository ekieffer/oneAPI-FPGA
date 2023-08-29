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
        #include <sycl/sycl.hpp>
        #include <sycl/ext/intel/fpga_extensions.hpp>
        #include <iomanip>
        #include <iostream>
        #include <string>
        #include <vector>
        
        #include <boost/align/aligned_allocator.hpp>
        
        using namespace sycl;
        
        // Forward declare the kernel name in the global scope.
        // This FPGA best practice reduces name mangling in the optimization reports.
        template <int unroll_factor> class VAdd;
        
        // This function instantiates the vector add kernel, which contains
        // a loop that adds up the two summand arrays and stores the result
        // into sum. This loop will be unrolled by the specified unroll_factor.
        template <int unroll_factor>
        void VecAdd(const std::vector<float> &summands1,
                    const std::vector<float> &summands2, std::vector<float> &sum,
                    size_t array_size) {
                    
        #if FPGA_SIMULATOR
          auto selector = sycl::ext::intel::fpga_simulator_selector_v;
        #elif FPGA_HARDWARE
          auto selector = sycl::ext::intel::fpga_selector_v;
        #else  // #if FPGA_EMULATOR
          auto selector = sycl::ext::intel::fpga_emulator_selector_v;
        #endif
        
          try {
            queue q(selector,property::queue::enable_profiling{});
        
            auto device = q.get_device();
        
            std::cout << "Running on device: "
                      << device.get_info<sycl::info::device::name>().c_str()
                      << std::endl;
        
            buffer buffer_summands1(summands1);
            buffer buffer_summands2(summands2);
            buffer buffer_sum(sum);
        
            event e = q.submit([&](handler &h) {
              accessor acc_summands1(buffer_summands1, h, read_only);
              accessor acc_summands2(buffer_summands2, h, read_only);
              accessor acc_sum(buffer_sum, h, write_only, no_init);
        
              h.single_task<VAdd<unroll_factor>>([=]()
                                                 [[intel::kernel_args_restrict]] {
                // Unroll the loop fully or partially, depending on unroll_factor
                #pragma unroll unroll_factor
                for (size_t i = 0; i < array_size; i++) {
                  acc_sum[i] = acc_summands1[i] + acc_summands2[i];
                }
              });
            });
        
            double start = e.get_profiling_info<info::event_profiling::command_start>();
            double end = e.get_profiling_info<info::event_profiling::command_end>();
            // convert from nanoseconds to ms
            double kernel_time = (double)(end - start) * 1e-6;
        
            std::cout << "unroll_factor " << unroll_factor
                      << " kernel time : " << kernel_time << " ms\n";
            std::cout << "Throughput for kernel with unroll_factor " << unroll_factor
                      << ": ";
            std::cout << std::fixed << std::setprecision(3)
        #if defined(FPGA_SIMULATOR)
                      << ((double)array_size / kernel_time) / 1e3f << " MFlops\n";
        #else
                      << ((double)array_size / kernel_time) / 1e6f << " GFlops\n";
        #endif
        
          } catch (sycl::exception const &e) {
            // Catches exceptions in the host code
            std::cerr << "Caught a SYCL host exception:\n" << e.what() << "\n";
        
            // Most likely the runtime couldn't find FPGA hardware!
            if (e.code().value() == CL_DEVICE_NOT_FOUND) {
              std::cerr << "If you are targeting an FPGA, please ensure that your "
                           "system has a correctly configured FPGA board.\n";
              std::cerr << "Run sys_check in the oneAPI root directory to verify.\n";
              std::cerr << "If you are targeting the FPGA emulator, compile with "
                           "-DFPGA_EMULATOR.\n";
            }
            std::terminate();
          }
        }
        
        int main(int argc, char *argv[]) {
        #if defined(FPGA_SIMULATOR)
          size_t array_size = 1 << 4;
        #else
          size_t array_size = 1 << 26;
        #endif
        
          if (argc > 1) {
            std::string option(argv[1]);
            if (option == "-h" || option == "--help") {
              std::cout << "Usage: \n<executable> <data size>\n\nFAILED\n";
              return 1;
            } else {
              array_size = std::stoi(option);
            }
          }
        
          std::vector<float,boost::alignment::aligned_allocator<float,64>> summands1(array_size);
          std::vector<float,boost::alignment::aligned_allocator<float,64>> summands2(array_size);
        
          std::vector<float,boost::alignment::aligned_allocator<float,64>> sum_unrollx1(array_size);
          std::vector<float,boost::alignment::aligned_allocator<float,64>> sum_unrollx2(array_size);
          std::vector<float,boost::alignment::aligned_allocator<float,64>> sum_unrollx4(array_size);
          std::vector<float,boost::alignment::aligned_allocator<float,64>> sum_unrollx8(array_size);
          std::vector<float,boost::alignment::aligned_allocator<float,64>> sum_unrollx16(array_size);
        
          // Initialize the two summand arrays (arrays to be added to each other) to
          // 1:N and N:1, so that the sum of all elements is N + 1
          for (size_t i = 0; i < array_size; i++) {
            summands1[i] = static_cast<float>(i + 1);
            summands2[i] = static_cast<float>(array_size - i);
          }
        
          std::cout << "Input Array Size:  " << array_size << "\n";
        
          // Instantiate VecAdd kernel with different unroll factors: 1, 2, 4, 8, 16
          // The VecAdd kernel contains a loop that adds up the two summand arrays.
          // This loop will be unrolled by the specified unroll factor.
          // The sum array is expected to be identical, regardless of the unroll factor.
          VecAdd<1>(summands1, summands2, sum_unrollx1, array_size);
          VecAdd<2>(summands1, summands2, sum_unrollx2, array_size);
          VecAdd<4>(summands1, summands2, sum_unrollx4, array_size);
          VecAdd<8>(summands1, summands2, sum_unrollx8, array_size);
          VecAdd<16>(summands1, summands2, sum_unrollx16, array_size);
        
          // Verify that the output data is the same for every unroll factor
          for (size_t i = 0; i < array_size; i++) {
            if (sum_unrollx1[i] != summands1[i] + summands2[i] ||
                sum_unrollx1[i] != sum_unrollx2[i] ||
                sum_unrollx1[i] != sum_unrollx4[i] ||
                sum_unrollx1[i] != sum_unrollx8[i] ||
                sum_unrollx1[i] != sum_unrollx16[i]) {
              std::cout << "FAILED: The results are incorrect\n";
              return 1;
            }
          }
          std::cout << "PASSED: The results are correct\n";
          return 0;
        }
        ```
    === "Solution"
        * Increasing the unroll factor improve throughput    
        * Nonetheless, unrolling large loops should be avoided as it would require a large amount of hardware
        !!! warning "Recording kernel time"
            * In this example, we have also seen how to record kernel time.
            * Using the property `property::queue::enable_profiling{}`




## Avoiding nested loops

## Memory Coalescing

## Local memory

## Task parallelism with Inter-Kernel Pipes
