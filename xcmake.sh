#!/bin/sh

CONDA_ENV=sfm
WHERE_OPENCV=../opencv
WHERE_OPENCV_CONTRIB=../opencv_contrib

cmake3 -D CMAKE_BUILD_TYPE=RELEASE \
	-D CMAKE_INSTALL_PREFIX=/usr/local \
	-D INSTALL_C_EXAMPLES=OFF \
	-D INSTALL_PYTHON_EXAMPLES=ON \
	-D OPENCV_EXTRA_MODULES_PATH=$WHERE_OPENCV_CONTRIB/modules \
	-D PYTHON2_EXECUTABLE=/usr/bin/python2 \
	-D PYTHON3_EXECUTABLE=$HOME/miniconda3/envs/$CONDA_ENV/bin/python \
	-D PYTHON_LIBRARIES=$HOME/miniconda3/envs/$CONDA_ENV/lib/libpython3.7m.so \
	-D PYTHON3_INCLUDE_DIRS=$HOME/miniconda3/envs/$CONDA_ENV/include/python3.7m \
	-D BUILD_opencv_python3=ON \
	-D PYTHON3_NUMPY_INCLUDE_DIRS=/apps/miniconda3/envs/sfm/lib/python3.7/site-packages/numpy/core/include \
	-D OPENCV_ENABLE_NONFREE=ON \
	$WHERE_OPENCV
