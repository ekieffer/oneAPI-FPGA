# Introduction to FPGA programming with Intel® oneAPI

[Intel® oneAPI](https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html#gs.3c0top) is a software development toolkit from Intel designed to simplify the process of developing high-performance applications for various types of computing architecture. It aims to provide a unified and simplified programming model for CPUs, GPUs, FPGAs, and other types of hardware, such as AI accelerators, allowing developers to use a single codebase for multiple platforms.

One of the main components of oneAPI is the [Data Parallel C++ (DPC++)](https://www.intel.com/content/www/us/en/developer/videos/dpc-part-1-introduction-to-new-programming-model.html#gs.3c0wb4), an open, standards-based language built upon the ISO C++ and SYCL standards. DPC++ extends C++ with features like parallel programming constructs and heterogeneous computing support, providing developers with the flexibility to write code for different types of hardware with relative ease.

In addition to DPC++, oneAPI includes a range of libraries designed to optimize specific types of tasks, such as machine learning, linear algebra, and deep learning. These include oneDNN for deep neural networks, oneMKL for math kernel library, and oneDAL for data analytics, among others.

It's important to note that Intel oneAPI is part of Intel's broader strategy towards open, standards-based, cross-architecture programming, which is intended to reduce the complexity of application development and help developers leverage the capabilities of different types of hardware more efficiently and effectively.

In this course, you will learn to:

* Use the DPC++ compiler to create executable for Intel FPGA hardware
* Discover the SYCL C++ abstraction layer
* How to move data from and to FPGA hardware
* Optimize FPGA workflows

!!! danger "Remark"
    This course is not intended to be exhaustive. In addition, the described tools and features are constantly evolving. We try our best to keep it up to date. 

## Who is the course for ?

This course is for students, researchers, enginners wishing to discover how to use oneAPI to program FPGA. This course do not requires any knowledge of SYCL/DPC++, however, participants should have some experience with modern C++. [Lambdas](https://en.cppreference.com/w/cpp/language/lambda), [class deduction templates](https://en.cppreference.com/w/cpp/language/class_template_argument_deduction), etc ... should be at least known before digging into this course. 

We recommend the excellent book: "[Professional C++ (5th Edition)](https://isbnsearch.org/isbn/9781119695400)" by Marc Gregoire.

## About this course

This course has been developed in the context of the [EuroCC National Competence Center Luxembourg](https://supercomputing.lu/). 



