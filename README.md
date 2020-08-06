# WS_demo

## Dependencies
- Tested Cuda versions: 9.0, 10.0
- Yarp

### Python packages
- Tested with Python 3.5

### For the tracker
- **numpy** (tested version: 1.13.1) e.g. `python3.5 -m pip install numpy==1.13.1`
- **opencv-python** (tested version: 3.3.0.10) e.g. `python3.5 -m pip install opencv-python==3.3.0.10`
- **tensorflow-gpu** (tested versions: 1.5.0 for Cuda 9.0 and 1.13.1 for Cuda 10.0) e.g. `python3.5 -m pip install opencv-python==1.5.0`

Then follow the installation instructions reported at this [link](https://github.com/danielgordon10/re3-tensorflow), cloning the repository in the `external` folder.

## Installation
```
git clone https://github.com/Arya07/WS_demo.git
cd WS_demo
mkdir build
ccmake ../
make 
make install
```
