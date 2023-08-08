# Writing and running SYCL program for Intel® FPGA cards

## Setups

Please clone first the [oneAPI-sample](https://github.com/oneapi-src/oneAPI-samples.git) repository with the `git clone https://github.com/oneapi-src/oneAPI-samples.git` in your home folder.

Once the repository cloned, you should see the following hierarchy:

```bash
$ tree -d -L 2 oneAPI-samples
oneAPI-samples
├── AI-and-Analytics
│   ├── End-to-end-Workloads
│   ├── Features-and-Functionality
│   ├── Getting-Started-Samples
│   ├── images
│   └── Jupyter
├── common
│   └── stb
├── DirectProgramming
│   ├── C++
│   ├── C++SYCL
│   ├── C++SYCL_FPGA
│   └── Fortran
├── Libraries
│   ├── oneCCL
│   ├── oneDAL
│   ├── oneDNN
│   ├── oneDPL
│   ├── oneMKL
│   └── oneTBB
├── Publications
│   ├── DPC++
│   └── GPU-Opt-Guide
├── RenderingToolkit
│   ├── GettingStarted
│   └── Tutorial
├── Templates
│   └── cmake
└── Tools
    ├── Advisor
    ├── ApplicationDebugger
    ├── Benchmarks
    ├── GPU-Occupancy-Calculator
    ├── Migration
    └── VTuneProfiler
```

* As you can see Intel provides numerous code samples and examples to help your grasping the power of the oneAPI toolkit. 
* We are going to focus on `DirectProgramming/C++SYCL_FPGA`.
* Create a symbolic at the root of your home directory pointing to this folder:
```bash
$ cd
$ ln -s oneAPI-samples/DirectProgramming/C++SYCL_FPGA/Tutorials/GettingStarted
$ tree -d -L 2 GettingStarted
GettingStarted
├── fast_recompile
│   ├── assets
│   └── src
├── fpga_compile
│   ├── part1_cpp
│   ├── part2_dpcpp_functor_usm
│   ├── part3_dpcpp_lambda_usm
│   └── part4_dpcpp_lambda_buffers
└── fpga_template
    └── src
```
* The **fpga_compile** folder provides basic examples start compiling SYCL C++ code with the DPC++ compiler
* The **fpga_recompile** folder show you how to recompile quickly your code without having to rebuild the FPGA image
* The **fpga_template** is a starting template project that you can use to boostrap a project


## Discovering devices

Before targeting a specific hardware accelerator, you need to ensure that the sycl runtime is able to detect it.
!!! example "Commands"
    ```bash linenums="1"
    # Create permanent tmux session
    tmux new -s fpga_session
    # We need a job allocation on a FPGA node
    salloc -A p200117 -t 48:00:00 -q default -p fpga -N 1
    # In order to use the  intel-compiler-2023.2.1
    module use /project/home/p200117/apps/u100057/easybuild/modules/all
    module load 520nmx/20.4
    # The fpga_compile version setup all necessary environment variable to compile code
    module load intel-compilers/2023.2.1-fpga_compile
    sycl-ls
    ```

!!! success "Output"
    ```bash 
    [opencl:cpu:0] Intel(R) OpenCL, AMD EPYC 7452 32-Core Processor                 3.0 [2022.13.3.0.16_160000]
    [opencl:acc:1] Intel(R) FPGA Emulation Platform for OpenCL(TM), Intel(R) FPGA Emulation Device 1.2 [2022.13.3.0.16_160000]
    [opencl:acc:2] Intel(R) FPGA SDK for OpenCL(TM), p520_hpc_m210h_g3x16 : BittWare Stratix 10 MX OpenCL platform (aclbitt_s10mx_pcie0) 1.0 [2022.1]
    [opencl:acc:3] Intel(R) FPGA SDK for OpenCL(TM), p520_hpc_m210h_g3x16 : BittWare Stratix 10 MX OpenCL platform (aclbitt_s10mx_pcie1) 1.0 [2022.1]
    ```

* If you see the same output, you are all setup.

## Compilation (manually)
![](./images/compile_time-1.png)

* Recalling that full compilation can take hours depending on your application size.
* In this context, emulation and static report evaluation are keys to succeed in FPGA programming

!!! warning "Full compilation & hardware profiling"
    Don't try a classical debug approach while hoping to solve a problem using multiple design iterations in this condition. 
    HLS-FPGA programming can be very tedious but SYCL simplifies greatly the process.   

    


## First code

!!! example "GettingStarted/fpga_compile/part4_dpcpp_lambda_buffers/src/vector_add.cpp"
    ```cpp linenums="1"
    #include <iostream>
    
    // oneAPI headers
    #include <sycl/ext/intel/fpga_extensions.hpp>
    #include <sycl/sycl.hpp>
    
    // Forward declare the kernel name in the global scope. This is an FPGA best
    // practice that reduces name mangling in the optimization reports.
    class VectorAddID;
    
    void VectorAdd(const int *vec_a_in, const int *vec_b_in, int *vec_c_out,
                   int len) {
      for (int idx = 0; idx < len; idx++) {
        int a_val = vec_a_in[idx];
        int b_val = vec_b_in[idx];
        int sum = a_val + b_val;
        vec_c_out[idx] = sum;
      }
    }
    
    constexpr int kVectSize = 256;
    
    int main() {
      bool passed = true;
      try {
        // Use compile-time macros to select either:
        //  - the FPGA emulator device (CPU emulation of the FPGA)
        //  - the FPGA device (a real FPGA)
        //  - the simulator device
    #if FPGA_SIMULATOR
        auto selector = sycl::ext::intel::fpga_simulator_selector_v;
    #elif FPGA_HARDWARE
        auto selector = sycl::ext::intel::fpga_selector_v;
    #else  // #if FPGA_EMULATOR
        auto selector = sycl::ext::intel::fpga_emulator_selector_v;
    #endif
    
        // create the device queue
        sycl::queue q(selector);
    
        // make sure the device supports USM host allocations
        auto device = q.get_device();
    
        std::cout << "Running on device: "
                  << device.get_info<sycl::info::device::name>().c_str()
                  << std::endl;
    
        // declare arrays and fill them
        int * vec_a = new int[kVectSize];
        int * vec_b = new int[kVectSize];
        int * vec_c = new int[kVectSize];
        for (int i = 0; i < kVectSize; i++) {
          vec_a[i] = i;
          vec_b[i] = (kVectSize - i);
        }
    
        std::cout << "add two vectors of size " << kVectSize << std::endl;
        {
          // copy the input arrays to buffers to share with kernel
          sycl::buffer buffer_a{vec_a, sycl::range(kVectSize)};
          sycl::buffer buffer_b{vec_b, sycl::range(kVectSize)};
          sycl::buffer buffer_c{vec_c, sycl::range(kVectSize)};
    
          q.submit([&](sycl::handler &h) {
            // use accessors to interact with buffers from device code
            sycl::accessor accessor_a{buffer_a, h, sycl::read_only};
            sycl::accessor accessor_b{buffer_b, h, sycl::read_only};
            sycl::accessor accessor_c{buffer_c, h, sycl::read_write, sycl::no_init};
    
            h.single_task<VectorAddID>([=]() {
              VectorAdd(&accessor_a[0], &accessor_b[0], &accessor_c[0], kVectSize);
            });
          });
        }
        // result is copied back to host automatically when accessors go out of
        // scope.
    
        // verify that VC is correct
        for (int i = 0; i < kVectSize; i++) {
          int expected = vec_a[i] + vec_b[i];
          if (vec_c[i] != expected) {
            std::cout << "idx=" << i << ": result " << vec_c[i] << ", expected ("
                      << expected << ") A=" << vec_a[i] << " + B=" << vec_b[i]
                      << std::endl;
            passed = false;
          }
        }
    
        std::cout << (passed ? "PASSED" : "FAILED") << std::endl;
    
        delete[] vec_a;
        delete[] vec_b;
        delete[] vec_c;
      } catch (sycl::exception const &e) {
        // Catches exceptions in the host code.
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
      return passed ? EXIT_SUCCESS : EXIT_FAILURE;
    }
    ```
* The `vector_add.cpp` source file contains all the necessary to understand how to create a SYCL program
* **lines 4 and 5** are the minimal headers to include in your SYCL program
* **line 9** is a foward declaration of the kernel name
* **lines 11-19** is a fonction representing our kernel. Note the absence of `__kernel`, `__global` as it exists in OpenCL
* **lines 30-36** are pragmas defining whether you want a full compilation, a CPU emulation or the simulator
* **line 39** is the queue creation. The queue is bounded to a device. We will discuss it later in details.
* **lines 41-46** provides debugging information at runtime.
* **lines 48-54** instantiates 3 vectors. `vec_a` and `vec_b` are input C++ arrays and are initialized inside the next loop. `vec_c` is an output C++ array collecting computation results between `vec_a` and `vec_b`.
* **lines 60-62** create buffers for each vector and specify their size. The runtime copies the data to the FPGA global memory when the kernel starts
* **line 64** submits a command group to the device queue 
* **lines 66-68** relies on accessor to infer data dependencies. "read_only" accessor have to wait for data to be fetched. "no_init" option indicates ito the runtime know that the previous contents of the buffer can be discarded
* **lines 70-73** starts a single tasks (single work-item) and call the kernel function
* **lines 99-105** catch SYCL exceptions and terminate the execution

### Emulation

### Static reports

### Full compilation

### Build automation with CMake



