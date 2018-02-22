#preparing a worker cloud for picture day!
#(as in, the stuff that can be done pre-snapshot, so no disc mounting etc)

#log onto delta.internal.sanger.ac.uk, instances, launch instance, name it something informative
#instance flavour: some sort of small (they're all the same, I used m1.small)
#it can't be a tiny, as some R packages fail to compile due to not enough RAM on a tiny
#boot from image, set image to trusty-isg-docker
#access & security tab, tick default + ssh + icmp
#networks tab, make sure cloudforms is dragged in
#once spawned, press the little arrow on the far right of the instance's row and associate a floating IP

#R time to begin!
#recent R setups require some non-standard apt-get repositories, so let's set them up
echo "deb https://cran.ma.imperial.ac.uk/bin/linux/ubuntu trusty/" | sudo tee -a /etc/apt/sources.list
#then add the corresponding apt key using this call
#sometimes fails because reasons, just call it again in that case
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
#good enough, let's install R
sudo apt-get update && sudo apt-get -y install r-base

#trusty-isg-docker comes with a python3... but an old one
#set up an up to date one with pip!
sudo add-apt-repository -y ppa:jonathonf/python-3.6
sudo apt-get update && sudo apt-get -y install python3.6-dev
#set up an alias so calling python3 fires up python3.6
echo "alias python3=python3.6" | sudo tee -a ~/.bashrc && exec bash
cd ~ && wget https://bootstrap.pypa.io/get-pip.py
#sudo don't care about aliases
sudo python3.6 get-pip.py && rm get-pip.py

#set up irods
wget ftp://ftp.renci.org/pub/irods/releases/4.1.10/ubuntu14/irods-icommands-4.1.10-ubuntu14-x86_64.deb
wget ftp://ftp.renci.org/pub/irods/releases/4.1.10/ubuntu14/irods-runtime-4.1.10-ubuntu14-x86_64.deb
wget ftp://ftp.renci.org/pub/irods/releases/4.1.10/ubuntu14/irods-dev-4.1.10-ubuntu14-x86_64.deb
#this will cry about missing dependencies, just ignore it and call the apt-get -y -f install below
sudo dpkg -i irods-icommands-4.1.10-ubuntu14-x86_64.deb irods-runtime-4.1.10-ubuntu14-x86_64.deb irods-dev-4.1.10-ubuntu14-x86_64.deb
sudo apt-get -y -f install && rm *.deb
#no actual configuration at this stage to keep it user agnostic

#we also need samtools, fresh ones with CRAM support
#and in turn, samtools wants htslib present
cd ~ && git clone https://github.com/samtools/htslib && cd htslib
sudo apt-get -y install libbz2-dev liblzma-dev libcurl4-openssl-dev
autoheader
autoconf
./configure
make
sudo make install
#DO NOT DELETE ~/htslib!! OR SAMTOOLS WILL CRY!!

#so now we can get samtools proper going
cd ~ && git clone https://github.com/samtools/samtools && cd samtools
sudo apt-get -y install libncurses5-dev
#ignore the warning autoheader spits out
autoheader
autoconf -Wno-syntax
./configure
make
sudo make install
#leave this just in case, you never know

#some more all-purpose stuff in bcftools and bedtools
cd ~ && git clone https://github.com/samtools/bcftools && cd bcftools
make
sudo make install
sudo apt-get -y install bedtools

#R package time!
#deal with the mountain of dependencies, some of which are external and quiet about it
sudo apt-get -y install libgsl0-dev libxml2-dev libboost-all-dev
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get update && sudo apt-get -y install openjdk-8-jdk
#and now setting up R packages! this runs forever, but also sets up everything humanity ever invented
#the CRAN has to be hard-wired or the cellranger kit can't be installed from the command line because reasons
echo 'options(repos=structure(c(CRAN="https://cran.ma.imperial.ac.uk/")))' > ~/.Rprofile
sudo R -e 'source("https://bioconductor.org/biocLite.R"); biocLite(c("edgeR","DESeq2","BiocParallel","scater","scran","SC3","monocle","destiny","pcaMethods","zinbwave","GenomicAlignments","RSAMtools")); install.packages(c("tidyverse","devtools","Seurat","vcfR","igraph","car")); source("http://cf.10xgenomics.com/supp/cell-exp/rkit-install-2.0.0.R"); devtools::install_github("velocyto-team/velocyto.R")'
#EmptyDrops is special and lives somewhere else
cd ~ && git clone https://github.com/TimothyTickle/hca-jamboree-cell-identification
cd hca-jamboree-cell-identification/src/poisson_model && sudo R CMD INSTALL package
cd ~ && sudo rm -r hca-jamboree-cell-identification

#since stuff like bcftools is preemptively set up, may as well do biobambam2 too
#biobambam2 and libmaus2 are not super nice when compiled from source, but can be apt-getted apparently
sudo add-apt-repository -y ppa:gt1/staden-io-lib-trunk-tischler
sudo add-apt-repository -y ppa:gt1/libmaus2
sudo add-apt-repository -y ppa:gt1/biobambam2
sudo apt-get update && sudo apt-get -y install libmaus2-dev biobambam2

#python package time!
#numpy/Cython need to be installed separately before everything else because otherwise GPy/velocyto get sad
sudo pip3 install numpy Cython
sudo pip3 install GPy scanpy sklearn jupyter velocyto snakemake pytest
cd ~ && git clone https://github.com/GPflow/GPflow
cd GPflow && sudo pip3 install .
cd ~ && git clone https://github.com/SheffieldML/GPclust
cd GPclust && sudo pip3 install .

#the Julia thing!
cd ~ && wget https://julialang-s3.julialang.org/bin/linux/x64/0.6/julia-0.6.2-linux-x86_64.tar.gz
tar -xzvf julia-0.6.2-linux-x86_64.tar.gz && rm julia-0.6.2-linux-x86_64.tar.gz
mv julia-d386e40c17 julia-0.6.2 && sudo ln -s ~/julia-0.6.2/bin/julia /usr/local/bin/julia

#Rstudio!
sudo apt-get -y install gdebi-core
wget https://download2.rstudio.org/rstudio-server-1.1.423-amd64.deb
#write Y when prompted, it defaults to N for some reason
sudo gdebi rstudio-server-1.1.423-amd64.deb && rm rstudio-server-1.1.423-amd64.deb

#the default rstudio port is occupied by something else. switch to port 8765
echo 'www-port=8765' | sudo tee -a /etc/rstudio/rserver.conf
sudo rstudio-server verify-installation

#pre-download the CRAM cache
cd ~ && rsync -P <user-id>@farm3-login.internal.sanger.ac.uk:/lustre/scratch117/cellgen/team269/kp9/24013_1#1.cram .
samtools fastq -1 24013-1.fastq -2 24013-2.fastq 24013_1#1.cram && rm 24013*

#with that, the cloud is almost ready for picture day!
#just need to comment out a thing that happens when a new cloud gets spun up in /etc/fstab
#as if it isn't undone, making a cloud from the snapshot will try to find a mount, fail and die
sudo sed 's/\/dev\/vdb/#\/dev\/vdb/g' -i /etc/fstab

#go back to delta, instances, create snapshot of the instance, name it something useful (basecloud comes to mind)
#once it saves, ssh back into the instance you snapshotted and undo the commenting out you just did
#if the instance becomes inaccessible, go back to delta and hard reboot it
#(or just kill it and spin up a new one from the snapshot, then you get to skip this)
sudo sed 's/#\/dev\/vdb/\/dev\/vdb/g' -i /etc/fstab
