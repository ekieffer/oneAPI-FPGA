# Developing SYCL programs for Intel® FPGA cards

## Anatomy of a SYCL program

[![](./images/sycl_program.png)](https://www.khronos.org/files/sycl/sycl-2020-reference-guide.pdf)

## Data Management
In the context of SYCL, Unified Shared Memory (USM) and buffers represent two different ways to handle memory and data management. They offer different levels of abstraction and ease of use, and the choice between them may depend on the specific needs of an application. Here's a breakdown of the differences:

### Unified Shared Memory (USM)

Unified Shared Memory is a feature that simplifies memory management by providing a shared memory space across the host and various devices, like CPUs, GPUs, and FPGAs. USM provides three different types of allocations:

1. **Device Allocations**: Allocated memory is accessible only by the device.
2. **Host Allocations**: Allocated memory is accessible by the host and can be accessed by devices. However, the allocated memory is stored on the host global memory. 
3. **Shared Allocations**: Allocated memory is accessible by both the host and devices. The allocated memory is present in both global memories and it is synchronized between host and device.

USM allows for more straightforward coding, akin to standard C++ memory management, and may lead to code that is easier to write and maintain. 

!!! warning "FPGA support"
    SYCL USM host allocations are only supported by some BSPs, such as the Intel® FPGA Programmable Acceleration Card (PAC) D5005 (previously known as Intel® FPGA Programmable Acceleration Card (PAC) with Intel® Stratix® 10 SX FPGA). Check with your BSP vendor to see if they support SYCL USM host allocations.

Using SYCL, you can verify if you have access to the different features:

!!! example "Verify USM capabilities"
    ```cpp
    if (!device.has(sycl::aspect::usm_shared_allocations)) {
        # Try to default to host allocation only
        if (!device.has(sycl::aspect::usm_host_allocations)) {
            # Default to device and explicit data movement
            std::array<int,N> host_array;
            int *my_array = malloc_device<int>(N, Q);
        }else{
            # Ok my_array is located on host memory but transferred to device as needed
            int* my_array = malloc_host<int>(N, Q);
        }
    }else{
            # Ok my_array is located on both global memories and synchronized automatically 
            int* shared_array = malloc_shared<int>(N, Q);
    }
    ```
!!! warning "That's not all"
    * Concurrent accesses and atomic modificationes are not necessarily available even if you have host and shared capabilities.
    * You need to verify `aspect::usm_atomic_shared_allocations` and `aspect::usm_atomic_host_allocations`.

!!! warning "Bittware 520N-MX"
    The USM host allocations is not supported by some BSPs. We will therefore use explicit data movement

!!! tig "Explicit USM"
    === "Question"
        * Go to the `GettingStarted/fpga_compile/part4_dpcpp_lambda_buffers/src`
        * Replace the original code with explicit USM code 
        * Verify your code using emulation

    === "Solution"
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
            int host_vec_a[kVectSize];
            int host_vec_b[kVectSize];
            int host_vec_c[kVectSize];
            int * vec_a = malloc_device<int>(kVectSize,q);
            int * vec_b = malloc_device<int>(kVectSize,q);
            int * vec_c = malloc_device<int>(kVectSize,q);
            for (int i = 0; i < kVectSize; i++) {
              host_vec_a[i] = i;
              host_vec_b[i] = (kVectSize - i);
            }

            std::cout << "add two vectors of size " << kVectSize << std::endl;
            {
            
              q.memcpy(vec_a, host_vec_a, kVectSize * sizeof(int)).wait();
              q.memcpy(vec_b, host_vec_b, kVectSize * sizeof(int)).wait();



              q.single_task<VectorAddID>([=]() {
                  VectorAdd(vec_a, vec_b, vec_c, kVectSize);
                }).wait();
            }
            // result is copied back to host automatically when accessors go out of
            // scope.
            q.memcpy(host_vec_c, vec_c, kVectSize * sizeof(int)).wait();

            // verify that VC is correct
            for (int i = 0; i < kVectSize; i++) {
              int expected = host_vec_a[i] + host_vec_b[i];
              if (host_vec_c[i] != expected) {
                std::cout << "idx=" << i << ": result " << host_vec_c[i] << ", expected ("
                          << expected << ") A=" << host_vec_a[i] << " + B=" << host_vec_b[i]
                          << std::endl;
                passed = false;
              }
            }

            std::cout << (passed ? "PASSED" : "FAILED") << std::endl;

            sycl::free(vec_a,q);
            sycl::free(vec_b,q);
            sycl::free(vec_c,q);
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


## Kernel scope