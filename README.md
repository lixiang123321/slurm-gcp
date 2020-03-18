# Running the Image Matching Benchmark on GCP

The [Image Matching Benchmark](https://github.com/vcg-uvic/image-matching-benchmark) provides a new evaluation framework for local features and robust matching algorithms for the purposes of wide-baseline image matching and 3D reconstruction. The benchmark requires heavy compute and is parallelized through the [Slurm](https://slurm.schedmd.com/) job scheduler. It can run sequentially on a desktop computer, but this is not an efficient solution for extensive testing.

This repository contains instructions to set up Slurm and the benchmark on a scalable, on-demand cluster on the Google Cloud Platform (GCP). It is a fork, with custom installation instructions, of [SchedMD/slurm-gcp](https://github.com/SchedMD/slurm-gcp), which relies on CentOS. You can find the original README file [here](README_schedmd.md). Please note that new GCP customers get $300 in [free credit](https://cloud.google.com/free).

Links:

* [Image Matching Benchmark](https://github.com/vcg-uvic/image-matching-benchmark)
* [Image Matching Challenge](https://vision.uvic.ca/image-matching-challenge/)
* [Paper](https://arxiv.org/abs/2003.01587)

If you use this benchmark, please cite the paper:

```
@article{Jin2020,
    author={Yuhe Jin and Dmytro Mishkin and Anastasiia Mishchuk and Jiri Matas and Pascal Fua and Kwang Moo Yi and Eduard Trulls},
    title={{Image Matching across Wide Baselines: From Paper to Practice}},
    journal={arXiv},
    year={2020}
}
```

### Cluster Installation

First, [install](https://cloud.google.com/sdk/install) and [configure](https://cloud.google.com/sdk/docs/initializing) the Google Cloud SDK. [Create](https://cloud.google.com/sdk/gcloud/reference/projects/create) a project. You may use the command-line SDK or the [web tools](https://console.cloud.google.com). You may also want to check out the original (benchmark-agnostic) README file for this repository.

Make sure you are authenticated and using the correct project:

```bash
$ gcloud config list
[core]
account = <redacted>@gmail.com
disable_usage_reporting = True
project = benchmark-<redacted>

Your active configuration is: [default]
```

Then, edit [./slurm-cluster.yaml](slurm-cluster.yaml). In particular:

* `cluster_name` (default: "benchmark"): Change the name for your deployment, if you wish.
* `max_node_count`: Maximum number of compute VMs that will be instantiated.
* `controller_secondary_disk_size_gb`: We recommmend a separate drive to store the data, which is more scalable. This is its size (it can be easily extended afterwards).
* `default_users`: Your email address.

Then, create the deployment:

```bash
gcloud deployment-manager deployments create <cluster_name> --config slurm-cluster.yaml
```

You may now log in to the deployment:

```bash
gcloud compute ssh <cluster_name>-login1
```

However, Slurm will continue setting up in the background. Wait for the terminal alert, log out, and log back in. This may take ~30 min. You may now check that the scheduler works:

```bash
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite     11  idle~ benchmark-compute[2-12]
debug*       up   infinite      1   idle benchmark-compute1
```

This shows a single instantiated compute node (`idle`). The rest (`idle~`) will be created on the fly. You may create a simple script to check that the scheduler works as expected:

```bash
$ cat test.bash
#!/bin/bash

wait 5
echo $HOSTNAME >> test.txt
```

And run it:

```bash
$ sbatch test.bash; sbatch test.bash
Submitted batch job 1
Submitted batch job 2
```

This should allocate a second node, as you queued two jobs. After a minute or two, you should see that a second node has been allocated:

```bash
$ sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
debug*       up   infinite     10  idle~ benchmark-compute[3-12]
debug*       up   infinite      2   idle benchmark-compute[1-2]

$ cat test.txt
benchmark-compute1
benchmark-compute2
```

If you have any issues, Slurm may not have been set up correctly. A common problem is that your user may not have permissions. If so, you can run `id` on the command line to get your uid and add it manually:

```bash
$ sudo /apps/slurm/current/bin/sacctmgr create user <uid> account=default
 Adding User(s)
  <uid>
 Associations =
  U = <uid> A = default    C = benchmark
 Non Default Settings
Would you like to commit changes? (You have 30 seconds to decide)
(N/y): y
```

### Benchmark Set-up

First, install miniconda:

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
```

Then, create a conda environment with the required dependencies:

```bash
source ~/.bashrc
conda deactivate
git clone https://github.com/vcg-uvic/image-matching-benchmark
git submodule update --init
cd image-matching-benchmark
conda env create -f system/conda_env_centos-7.7.yml
```

And make it the default:

```bash
echo "conda activate sfm" >> ~/.bashrc
source ~/.bashrc
```

You can install OpenCV from conda, but it may cause issues when compiling some of the RANSAC algorithms used by the benchmark. We recommend compiling from source. First, download the main and contrib repositories (please note that the latter contains non-free modules; the benchmark will work without it, but you will lose access to SIFT and other methods):

```bash
mkdir ~/opencv
cd ~/opencv
git clone https://github.com/opencv/opencv.git
git clone https://github.com/opencv/opencv_contrib.git
```

We bundle a script to set it up: [xcmake.sh](xcmake.sh). You can copy it to the deployment (into `~/opencv`) and run it:

```bash
cd ~/opencv
mkdir build
cd build
source scl_source enable devtoolset-8
bash ../xcmake.sh
make -j2
sudo make install
```

And link the library inside conda:

```bash
ln -s /home/<username>/opencv/build/lib/python3/cv2.cpython-37m-x86_64-linux-gnu.so ~/miniconda3/envs/sfm/lib/python3.7/site-packages/cv2.so
```

You can now call `python` and `import cv2` to ensure that this worked correctly.

Now, you can install PyRANSAC:

```bash
cd ~
git clone https://github.com/ducha-aiki/pyransac.git
cd pyransac
pip install -e .
```

And MAGSAC:

```bash
cd ~
git clone https://github.com/ducha-aiki/pymagsac.git
cd pymagsac
pip install -e .
```

Note that all of these are installed into the common conda installation, so they should not require re-imaging the compute node.

### Getting the data

We recommmend you use a separate drive to store the data and intermediate results, which can quickly snowball; external drives are easier to extend. Using the default configuration file, this drive is mounted on `/mnt/disks/sec`, owned by root. First, update its permissions:

```bash
sudo chown -R <username>:<username> /mnt/disks/sec
```

Then, copy the data

```bash
cd /mnt/disks/sec
wget https://vision.uvic.ca/imw-challenge/ValidationData/imw2020-valid.tar.gz
tar xvf imw2020-valid.tar.gz
mkdir data
mv imw2020-valid data/phototourism
ln -s /mnt/disks/sec/data ~/data
```

And create folders for the results, so they are stored on this drive:

```bash
mkdir /mnt/disks/sec/benchmark-results
mkdir /mnt/disks/sec/benchmark-visualization
ln -s /mnt/disks/sec/benchmark-results ~
ln -s /mnt/disks/sec/benchmark-visualization ~
```

### Testing

You can check that everything is ok by running the following command:

```bash
cd ~/image-matching-benchmark
python run.py --subset=val --json_method=example/configs/example-test.json --run_mode=interactive
```

This will run the example configuration files on a single-thread. To queue all jobs on the scheduler, simply remove the last flag:

```bash
python run.py --subset=val --json_method=example/configs/example-test.json
```

This will create many jobs and allocate multiple VMs:

```bash
$ squeue | grep benchmark
    10     debug 91cfb073 etru1927 CF       0:37      1 benchmark-compute2
    11     debug 64b0b9f8 etru1927 CF       0:37      1 benchmark-compute3
    12     debug 4d1a3b3a etru1927 CF       0:37      1 benchmark-compute4
    13     debug f7f37375 etru1927 CF       0:37      1 benchmark-compute5
    14     debug 8bcef30b etru1927 CF       0:37      1 benchmark-compute6
    16     debug daa86a62 etru1927 CF       0:37      1 benchmark-compute7
    28     debug 0a77e828 etru1927 CF       0:34      1 benchmark-compute8
     7     debug 448f19e5 etru1927  R       0:40      1 benchmark-compute1
```

The results will be saved into `packed-val`, and the visualizations into `../benchmark-visualization`.

### Debugging

This deployment will install additional packages to the compute node, as specified by `scripts/custom-compute-install`. System updates may cause this process to fail, **silently.** If that happens (you can for instance check if colmap has been installed properly after set up) you may want to debug this. You can log to the permanent compute node:

```bash
gcloud compute ssh benchmark-compute1 --internal-ip
```

And run the instructions on the installation script manually. After fixing any issues, you can regenerate the image that new VMs will be instantiated from. To do so, first stop all your VMs ([recommended by GCP](https://cloud.google.com/compute/docs/images/create-delete-deprecate-private-images)) and run the following command on the computer you used to create the deployment:

```bash
gcloud compute images create benchmark-compute-image-$(date '+%Y-%m-%d-%H-%M-%S') --source-disk benchmark-compute1 --source-disk-zone us-central1-b --force --family benchmark-image-family
```

Then deprecate the previous image using the [web console](https://console.cloud.google.com), reboot the VMs, instantiate `compute2` as in the example above, log in to this node, and check that the new binaries you installed on the permanent compute node (`compute1`) are visible.

You can also update the installation script once it works and create a new deployment, for simplicity.

### Additional considerations

This installation may charge a fixed amount (~$50/mo) even if you stop the VMs, which can be done from the web console, due to keeping the gateways. You may thus want to disable billing if you're not using the deployment. There might be a simple way to fix this but we are not investigating it.
