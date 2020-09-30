#preparing a worker cloud for picture day!
#(as in, the stuff that can be done pre-snapshot, so no disc mounting etc)

#log onto eta.internal.sanger.ac.uk, instances, launch instance, name it something informative
#source: bionic-server
#flavor: m1.tiny (the smaller the better, the more sizes can use this later)
#networks: ensure cloudforms_network is dragged in
#security groups: ssh and icmp (on top of default)
#once spawned, press the little arrow on the far right of the instance's row and associate a floating IP

#gotta do this to kick off proceedings. things change fast in apt land
sudo apt-get update

#R time to begin!
#add appropriate R PPA thingy for us to grab R from
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
sudo add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/'
sudo apt-get update
#install R, and various useful things
sudo apt-get -y install r-base build-essential xorg-dev libreadline-dev libc6-dev zlib1g-dev libbz2-dev liblzma-dev libcurl4-openssl-dev libcairo2-dev libpango1.0-dev tcl-dev tk-dev openjdk-8-jdk openjdk-8-jre gfortran

#Rstudio! keep this version if possible, 1.3.1093 had some libssl hiccup
sudo apt-get -y install gdebi-core
wget https://download2.rstudio.org/rstudio-server-1.1.463-amd64.deb
#write Y when prompted, it defaults to N for some reason
sudo gdebi rstudio-server-1.1.463-amd64.deb && rm rstudio-server-1.1.463-amd64.deb
#the default rstudio port is occupied by something else. switch to port 8765
echo 'www-port=8765' | sudo tee -a /etc/rstudio/rserver.conf
sudo rstudio-server verify-installation

#R package time!
#deal with the mountain of dependencies, some of which are external and quiet about it
sudo apt-get -y install libgsl0-dev libxml2-dev libboost-all-dev libssl-dev libhdf5-dev unzip libudunits2-dev libgdal-dev libgeos-dev libproj-dev
#and now setting up R packages! this runs forever, but also sets up everything humanity ever invented
#the ~/.Renviron thing is so that devtools::install_github() works
#and the javareconf is for rJava
echo 'options(repos=structure(c(CRAN="https://cran.ma.imperial.ac.uk/")))' > ~/.Rprofile
echo 'R_UNZIPCMD=/usr/bin/unzip' > ~/.Renviron
sudo R CMD javareconf
#the cellranger toolkit has been deprecated, and current R can't install it as too old
sudo R -e 'install.packages("BiocManager"); BiocManager::install(c("edgeR","DESeq2","BiocParallel","scater","scran","SC3","monocle","destiny","pcaMethods","zinbwave","GenomicAlignments","RSAMtools","M3Drop","DropletUtils","switchde","biomaRt","batchelor","Matrix.utils")); install.packages(c("tidyverse","devtools","Seurat","vcfR","igraph","car","ggpubr","rJava","SoupX")); devtools::install_github("velocyto-team/velocyto.R"); devtools::install_github("im3sanger/dndscv"); devtools::install_github("immunogenomics/harmony"); devtools::install_github("cole-trapnell-lab/leidenbase"); devtools::install_github("cole-trapnell-lab/monocle3")'

#many things of general utility
sudo apt-get -y install samtools bcftools bedtools htop parallel sshfs

#rclone is pretty good for google drive communication
curl https://rclone.org/install.sh | sudo bash

#python package time! start with pip
sudo apt-get -y install python3-pip
#numpy/Cython need to be installed separately before everything else because otherwise GPy/velocyto get sad
sudo apt-get -y install libfftw3-dev python3-tk bison flex
sudo pip3 install numpy Cython
#for some reason, llvmlite is now a massive pain
wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
sudo ./llvm.sh 10
rm llvm.sh
LLVM_CONFIG=/usr/lib/llvm-10/bin/llvm-config pip3 install llvmlite
#with that in place, this should hopefully run
sudo pip3 install python-igraph louvain leidenalg GPy scanpy sklearn jupyter velocyto snakemake pytest fitsne plotly ggplot cmake jupyterlab spatialde polo rpy2 bbknn scvelo wot cellphonedb pyscenic scirpy scvi-tools sccaf palantir
#scanpy is incomplete. the docs argument you need to install these by hand, in this order
#...and this also helps with run time, but is buried as a hint on one of the documentation pages
cd ~ && git clone https://github.com/DmitryUlyanov/Multicore-TSNE
cd Multicore-TSNE && sudo pip3 install .
cd ~ && sudo rm -r Multicore-TSNE
#other non-pip packages
sudo pip3 install tensorflow tensorflow-probability
cd ~ && git clone https://github.com/theislab/batchglm
cd batchglm && sudo pip3 install .
cd ~ && sudo rm -r batchglm
cd ~ && git clone https://github.com/theislab/diffxpy
cd diffxpy && sudo pip3 install .
cd ~ && sudo rm -r diffxpy

#post-jupyter setup of IRkernel
sudo R -e "devtools::install_github('IRkernel/IRkernel'); IRkernel::installspec()"

#set up irods
wget -qO - https://packages.irods.org/irods-signing-key.asc | sudo apt-key add -
echo "deb [arch=amd64] https://packages.irods.org/apt/ xenial main" | sudo tee /etc/apt/sources.list.d/renci-irods.list
sudo apt-get update
#this thing had some interactive installer pop up. three enters, then swapped to "NO" at NFS mention and stayed there
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ldap-utils sssd sssd-tools ldap-auth-config libldap-2.4-2 libpam-sss libnss-sss
sudo apt-get install -y irods-icommands=4.2.7 irods-runtime=4.2.7
wget http://people.renci.org/~tgr/sanger-427-imeta-dash-z/irods-icommands_4.2.7~xenial_amd64.deb
sudo dpkg -i irods-icommands_4.2.7~xenial_amd64.deb
rm irods-icommands_4.2.7~xenial_amd64.deb
DEFAULT_USER="ubuntu"
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
cd ~ && wget https://julialang-s3.julialang.org/bin/linux/x64/1.5/julia-1.5.2-linux-x86_64.tar.gz
tar -xzvf julia-1.5.2-linux-x86_64.tar.gz && rm julia-1.5.2-linux-x86_64.tar.gz
sudo ln -s ~/julia-1.5.2/bin/julia /usr/local/bin/julia

#Docker install (this only properly starts working after relogging into the instance)
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
sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -qq docker-ce
sudo adduser ubuntu docker

#libmaus2 and biobambam2, made easy again courtesy of a PPA
sudo add-apt-repository -y ppa:gt1/staden-io-lib-trunk-tischler
sudo add-apt-repository -y ppa:gt1/libmaus2
sudo add-apt-repository -y ppa:gt1/biobambam2
sudo apt-get update
sudo apt-get -y install libmaus2-dev biobambam2

#pre-download the CRAM cache
#(this lives in /nfs/disk69/ftp/pub/users/kp9 on the farm)
cd ~ && wget ftp://ftp.sanger.ac.uk/pub/users/kp9/sample.cram
samtools fastq -1 sample.fastq -2 sample-2.fastq sample.cram && rm sample*

#so this is apparently necessary
#or jupyter notebooks don't work
sudo chown -R ubuntu ~/.local

#assorted Peng stuff
sudo pip3 install MACS2
sudo apt-get -y install seqtk
cd ~ && wget https://cloud.biohpc.swmed.edu/index.php/s/4pMgDq4oAF9QCfA/download
mv download hisat2-2.2.1-Linux_x86_64.zip
unzip hisat2-2.2.1-Linux_x86_64.zip && rm hisat2-2.2.1-Linux_x86_64.zip
wget -r -np -nH --cut-dirs 3 ftp://ftp.sanger.ac.uk/pub/users/kp9/UCSC ~
chmod -R 755 ~/UCSC
sudo pip3 install cutadapt scrublet
cd ~ && git clone https://github.com/broadinstitute/picard.git
cd picard && ./gradlew shadowJar && cd ..

#fresh singularity for souporcell to work
sudo apt-get update
sudo apt-get install -y build-essential libssl-dev uuid-dev libgpgme11-dev squashfs-tools libseccomp-dev wget pkg-config git cryptsetup
export VERSION=1.13 OS=linux ARCH=amd64 && \  # Replace the values as needed
  wget https://dl.google.com/go/go$VERSION.$OS-$ARCH.tar.gz && \ # Downloads the required Go package
  sudo tar -C /usr/local -xzvf go$VERSION.$OS-$ARCH.tar.gz && \ # Extracts the archive
  rm go$VERSION.$OS-$ARCH.tar.gz    # Deletes the ``tar`` file
echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc && source ~/.bashrc
export VERSION=3.6.3 && # adjust this as necessary \
  wget https://github.com/sylabs/singularity/releases/download/v${VERSION}/singularity-${VERSION}.tar.gz && \
  tar -xzf singularity-${VERSION}.tar.gz && \
  cd singularity
./mconfig && make -C builddir && sudo make -C builddir install
cd .. && sudo rm -r go && rm -r singularity && rm singularity-3.6.3.tar.gz

#the cloud is now ready for picture day!
#go back to eta, instances, create snapshot of the instance, name it something useful (basecloud comes to mind)
