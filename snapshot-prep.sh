#preparing a worker cloud for picture day!
#(as in, the stuff that can be done pre-snapshot, so no disc mounting etc)

#log onto zeta.internal.sanger.ac.uk, instances, launch instance, name it something informative
#source: Bionic (none of the bionic variant images, we're going grassroots here)
#flavor: m1.tiny (the smaller the better, the more sizes can use this later)
#networks: ensure cloudforms_network is dragged in
#security groups: ssh and icmp (on top of default)
#once spawned, press the little arrow on the far right of the instance's row and associate a floating IP

#gotta do this to kick off proceedings. things change fast in apt land
sudo apt-get update

#R time to begin!
#installing R 3.5.0 from source
cd ~ && wget https://cran.r-project.org/src/base/R-3/R-3.5.0.tar.gz && tar -xzvf R-3.5.0.tar.gz && rm R-3.5.0.tar.gz
#https://cran.r-project.org/doc/manuals/r-release/R-admin.html#Essential-and-useful-other-programs-under-a-Unix_002dalike
#R wants all this stuff to be alive. use java 8 for rJava compatibility
sudo apt-get -y install build-essential xorg-dev libreadline-dev libc6-dev zlib1g-dev libbz2-dev liblzma-dev libcurl4-openssl-dev libcairo2-dev libpango1.0-dev tcl-dev tk-dev openjdk-8-jdk openjdk-8-jre gfortran
#the actual installation part. needs enable-R-shlib for rstudio support
cd R-3.5.0
./configure --enable-R-shlib=yes
make
make check
sudo make install
cd ~ && sudo rm -r R-3.5.0

#R package time!
#deal with the mountain of dependencies, some of which are external and quiet about it
sudo apt-get -y install libgsl0-dev libxml2-dev libboost-all-dev libssl-dev libhdf5-dev unzip
#and now setting up R packages! this runs forever, but also sets up everything humanity ever invented
#the CRAN has to be hard-wired or the cellranger kit can't be installed from the command line because reasons
#while in turn the ~/.Renviron thing is so that devtools::install_github() works
echo 'options(repos=structure(c(CRAN="https://cran.ma.imperial.ac.uk/")))' > ~/.Rprofile
echo 'R_UNZIPCMD=/usr/bin/unzip' > ~/.Renviron
sudo R -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("edgeR","DESeq2","BiocParallel","scater","scran","SC3","monocle","destiny","pcaMethods","zinbwave","GenomicAlignments","RSAMtools","M3Drop","DropletUtils","switchde","biomaRt")); install.packages(c("tidyverse","devtools","Seurat","vcfR","igraph","car","ggpubr","rJava")); source("http://cf.10xgenomics.com/supp/cell-exp/rkit-install-2.0.0.R"); devtools::install_github("velocyto-team/velocyto.R"); devtools::install_github("im3sanger/dndscv")'

#many things of general utility
sudo apt-get -y install samtools bcftools bedtools htop parallel sshfs

#python package time! start with pip
cd ~ && wget https://bootstrap.pypa.io/get-pip.py
sudo python3 get-pip.py && rm get-pip.py
#numpy/Cython need to be installed separately before everything else because otherwise GPy/velocyto get sad
sudo apt-get -y install libfftw3-dev python3-tk
sudo pip3 install numpy Cython
sudo pip3 install GPy scanpy sklearn jupyter velocyto snakemake pytest fitsne plotly ggplot cmake jupyterlab spatialde polo rpy2
#scanpy is incomplete. the docs argument you need to install these by hand, in this order
sudo pip3 install python-igraph
sudo pip3 install louvain
#...and this also helps with run time, but is buried as a hint on one of the documentation pages
cd ~ && git clone https://github.com/DmitryUlyanov/Multicore-TSNE
cd Multicore-TSNE && sudo pip3 install .
cd ~ && sudo rm -r Multicore-TSNE

#post-jupyter setup of IRkernel
sudo R -e "devtools::install_github('IRkernel/IRkernel'); IRkernel::installspec()"

#set up irods
wget ftp://ftp.renci.org/pub/irods/releases/4.1.10/ubuntu14/irods-icommands-4.1.10-ubuntu14-x86_64.deb
wget ftp://ftp.renci.org/pub/irods/releases/4.1.10/ubuntu14/irods-runtime-4.1.10-ubuntu14-x86_64.deb
wget ftp://ftp.renci.org/pub/irods/releases/4.1.10/ubuntu14/irods-dev-4.1.10-ubuntu14-x86_64.deb
sudo dpkg -i irods-icommands-4.1.10-ubuntu14-x86_64.deb irods-runtime-4.1.10-ubuntu14-x86_64.deb irods-dev-4.1.10-ubuntu14-x86_64.deb
rm *.deb
#internal.sanger.ac.uk configuration for irods can now be done snapshot side
cat > 60-resolve.yaml <<EOF
network:
    version: 2
    ethernets:
        ens3:
            dhcp4: true
            nameservers:
               search: [internal.sanger.ac.uk]
EOF
sudo mv 60-resolve.yaml /etc/netplan
sudo netplan generate
sudo netplan apply

#the Julia thing!
cd ~ && wget https://julialang-s3.julialang.org/bin/linux/x64/0.6/julia-0.6.2-linux-x86_64.tar.gz
tar -xzvf julia-0.6.2-linux-x86_64.tar.gz && rm julia-0.6.2-linux-x86_64.tar.gz
mv julia-d386e40c17 julia-0.6.2 && sudo ln -s ~/julia-0.6.2/bin/julia /usr/local/bin/julia

#Rstudio!
sudo apt-get -y install gdebi-core
wget https://download2.rstudio.org/rstudio-server-1.1.447-amd64.deb
#write Y when prompted, it defaults to N for some reason
sudo gdebi rstudio-server-1.1.447-amd64.deb && rm rstudio-server-1.1.447-amd64.deb
#the default rstudio port is occupied by something else. switch to port 8765
echo 'www-port=8765' | sudo tee -a /etc/rstudio/rserver.conf
sudo rstudio-server verify-installation

#Docker install (note the artful - at the time there was no bionic stable)
sudo groupadd docker
sudo mkdir /etc/docker
sudo chmod 0700 /etc/docker
sudo tee /etc/docker/daemon.json <<-EOF
	{
	"bip": "192.168.3.3/24",
	"mtu": 1380,
	"registry-mirrors": ["https://docker-hub-mirror.internal.sanger.ac.uk:5000"]
	}
EOF
sudo apt-get -y install apt-transport-https ca-certificates
echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu artful stable" | sudo tee -a /etc/apt/sources.list.d/docker.list
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-get update
sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -qq docker-ce
sudo adduser ubuntu docker

#new old school libmaus2 and biobambam2 setup
cd ~ && git clone https://github.com/gt1/libmaus2 && cd libmaus2
libtoolize
aclocal
autoreconf -i -f
./configure
make
sudo make install
cd ~ && git clone https://github.com/gt1/biobambam2 && cd biobambam2
autoreconf -i -f
./configure
make
sudo make install
#need to call this so that the libraries cache gets updated and biobambam2 actually sees libmaus2
sudo ldconfig -v
cd ~ && sudo rm -r libmaus2 && sudo rm -r biobambam2

#pre-download the CRAM cache
cd ~ && wget ftp://ngs.sanger.ac.uk/production/teichmann/kp9/sample.cram
samtools fastq -1 sample.fastq -2 sample-2.fastq sample.cram && rm sample*

#the cloud is now ready for picture day!
#go back to zeta, instances, create snapshot of the instance, name it something useful (basecloud comes to mind)