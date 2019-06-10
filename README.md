# Basic R/python Teichlab computational cloud

This bit of text is going to detail the process of creating a functional machine on the internal OpenStack cloud infrastructure, making use of a template pre-loaded with all sorts of computational goodies requested from all across the lab:

* **R/Rstudio:** edgeR, DESeq2, scater, scran, monocle3, destiny, pcaMethods, zinbwave, M3Drop, DropletUtils, switchde, biomaRt, tidyverse, devtools, Seurat, vcfR, igraph, car, ggpubr, rJava, cellrangerRkit, velocyto.R, dndscv, harmony, IRkernel
* **python3:** GPy, scanpy, sklearn, scvelo, bbknn, scrublet, palantir, wot, cellphonedb, pyscenic, diffxpy, jupyter, jupyterlab, velocyto, snakemake, pytest, fitsne, plotly, cmake, spatialDE, MulticoreTSNE, polo, rpy2, cutadapt
* **iRODS**
* **Docker**
* **Julia**
* **UCSC tools**
* **samtools, bcftools, biobambam2, bedtools, hisat2, htop, MACS2, parallel, picard, rclone, seqtk, sshfs**

If you don't see your preferred package on here, do not despair! A lot of the installed options come with a truckload of dependencies, so your everyday utility (ggplot2, numpy etc.) is here. And if it isn't here, you have the power to install more things within R/Rstudio, or via `sudo pip3` for python. There's also `apt-get` for more all-purpose stuff. The cloud does not come with mapping/genomics tools built in, those pipelines are supported by the second template mapcloud.

Monocle 3's quite easily reverted to version 2. Just call this: `sudo R -e 'remove.packages("monocle"); BiocManager::install("monocle")'`

### Basic OpenStack things

* The Teichlab allocation on OpenStack was estimated for 10 active users with reasonable computational needs, assuming a `m1.2xlarge` instance per head with a 2TB volume to boot. As such, try not to use more than its resource total (26 cores, 236,600 MB RAM, 2TB volume space) at a time between all your instances. If you do end up using more (dire computational straits happen), please free it up in a timely manner.
* Even when not extending past your bit of resources, try to keep your instance life to a minimum. I'm not saying kill off your cloud if you wait two hours between analyses, but if the machine has been sitting around idly for a week you should probably get rid of it. The templates come stocked with a lot of requested tools to make killing off your machines as painless as possible, as pretty much everything will be waiting for you when you make a new one. If you set up something particularly annoying that you don't want to do again, you can take a personalised snapshot of your cloud. I'll walk you through the steps later on in the document.
* Ideally, the volume storage should be mainly thought as space to let your analyses run and not an actual long-term storage option. You can quite easily copy data to/from the farm with `rsync`, once again I'll write how in a bit. I'd recommend saving all your analysis files to the mounted volumes as the built-in drive space of a lot of the cloud options is quite limited. Plus, you can theoretically swap volumes between machines, carrying the files across!
* `screen -DR` is your friend. This command opens up a screen that won't stop existing when you log out of your cloud. As such, you can call this command, launch your two-week analysis and disconnect, and it will still run. Once inside the screen, use `ctrl+a, ctrl+d` to exit. You can spawn extra screens with `ctrl+a, ctrl+c` and cycle through them with `ctrl+space`. Kill off any screens you don't need by typing `exit`. There's [a lot more](http://aperiodic.net/screen/quick_reference), but this is all I've needed so far.

### Getting onto Openstack

* In order to access the cloud, write servicedesk asking for:
	- an OpenStack account on tenant team205 (tenant is cloud slang for a group)
	- a switch to native iRODS authentication if you intend to use iRODS on your machines
	- if you requested the above, also a copy of your new native password, which you should immediately change via `ipasswd`
* Once your cloud account email arrives, follow the instructions to [retrieve your password](https://ssg-confluence.internal.sanger.ac.uk/pages/viewpage.action?pageId=66031299) and save it somewhere. Do not change it!
* Go onto [Eta](http://eta.internal.sanger.ac.uk) and log in with your Sanger user name and the password you just saved.
* Open up a terminal. Set yourself to the user you intend to connect to the cloud as. Write `ls ~/.ssh`. If you don't see an `id_rsa.pub`file, [generate an SSH key](https://docs.joyent.com/public-cloud/getting-started/ssh-keys/generating-an-ssh-key-manually/manually-generating-your-ssh-key-in-mac-os-x).
* Write `cat ~/.ssh/id_rsa.pub` and copy the entirety of what comes out.
* Go to the Compute tab of [Eta](http://eta.internal.sanger.ac.uk), then Instances. Press Launch Instance. Go to the Key Pair tab. Press Import Key Pair. Paste in the bit you just copied into Public Key. Name the key pair something informative, such as your Sanger user ID. Press Import Key Pair.
* Done! You can now access the website to create/manage your machines and volumes, and have set up SSH for connecting to the cloud from your computer.

### Creating a basic R/python machine from the image

* Log in to [Eta](http://eta.internal.sanger.ac.uk), go to the Compute tab, then Instances, press Launch Instance.
* In Details, name the instance something informative.
* In Source, under Select Boot Source, select Instance Snapshot. In the list that appears, find `basecloud` and press the little up arrow to the right.
* Switch to Flavor. The flavours are a dropdown of available resource allocations you can request. Pick any `m1` flavour `m1.small` or above. If you need more cores to run something, by all means go for it! However, be mindful of your tools' abilities to actually effectively use cores and RAM, and if you go for heavier flavours be extra vigilant with removing idle instances.
* In Networks, ensure that `cloudforms_network` is part of the network list. If it isn't, press the up arrow on the right hand side of its row and it should move up.
* In Security Groups, press the up arrow on the right hand side of the `cloudforms_icmp_in` and `cloudforms_ssh_in` rows.
* In Key Pair, ensure the one you created is selected. Press Launch Instance.
* While you wait for the machine to appear, switch to the Volumes tab (and then Volumes within there). Press Create Volume. Name the volume something informative, I usually just have it match the instance name. Enter a size in GB. Press Create Volume.
* Go back to Instances within the Compute tab. Once the machine spawns, press the little arrow in the right of the screen for your instance's entry and select Associate Floating IP. Pick one from the dropdown. Tomas's suggestion to stick to the same one is not a bad idea! If no floating IPs are available, quickly visit the Overview tab and see if the maximum number is in use. If not, head back to the previous screen and press the little plus to create a new one (confirm this with Allocate IP in the next box that shows up).
* Go back to the Volumes tab. Press the little arrow in the right of the screen for your volume's entry and select Manage Attachments. Pick your machine in the dropdown. Press Attach Volume.
* Done! You just created an instance and attached a volume to it. You can now connect to it via `ssh ubuntu@<floating-ip>`. Just a small bit of setup before you're all ready to go!

### SSH configuration

If you foresee yourself keeping an instance around for a long time (heavy computations happen!) or re-using the same floating IP, as per Tomas's suggestion, you can create an SSH configuration file to store the information for you. Open `~/.ssh/config` in your preferred text editor and add the following bit:

	Host <your-chosen-name>
		HostName <floating-ip>
		User ubuntu

Now you can just SSH or `rsync` with the cloud just by specifying the name you chose instead of the full `ubuntu@<floating-ip>` syntax, including when creating Rstudio/jupyter notebook connections!

### Machine-side setup

Once you SSH into the machine, you need to mount the volume you created. The following code chunk creates a file system on the drive space provided (skip if you're reattaching a volume you already used in another instance), mounts it, tweaks an internal configuration file to acknowledge its existence, makes you (ubuntu) the owner and then quickly "jogs" it to see that it works. In the summer of 2017, sometimes the volumes would spawn wrong and would hang the moment they were asked to do anything borderline resembling saving files, so the precautionary measure has been kept in place as a diagnostic tool.

	#start here if creating new volume
	sudo mkfs.ext4 /dev/vdb
	#start here if reattaching existing volume
	sudo mount /dev/vdb /mnt
	echo -e "/dev/vdb\t/mnt\text4\tdefaults\t0\t0" | sudo tee -a /etc/fstab
	sudo chown -R ubuntu: /mnt
	cd /mnt && dd if=/dev/zero of=deleteme oflag=direct bs=1M count=1024 && rm deleteme

If you intend to work with Rstudio, you'll need to setup login credentials for your user, i.e. ubuntu. To do this, call the following line and enter rstudio as your password, re-entering it immediately thereafter:

	sudo passwd ubuntu

If you intend to use iRODS, you need to grab your configuration from the farm, and then edit it to remove some farm-specific location information in `irods_environment.json`. Once that's done, type `iinit` and give it your iRODS password. Done! Once again, all the stuff is handled by a code snippet (you'll likely need to call the `rsync` alone and then you can paste the rest):

	rsync -Pr <user-id>@farm3-login.internal.sanger.ac.uk:~/.irods ~
	sed ':a;N;$!ba;s/,\n    "irods_plugins_home" : "\/opt\/renci\/icommands\/plugins\/"//g' -i ~/.irods/irods_environment.json
	iinit

And with that, you're good to go! Make use of a number of popular R/python packages, some basic utility like samtools, connect to Rstudio/jupyter notebooks remotely! Oh wait, how do I do that?

### Using Rstudio and jupyter notebooks/labs

If you intend to use your machine for Rstudio/jupyter notebooks from the comfort of your own computer, call the following command in your terminal:

	ssh -f ubuntu@<floating-ip> -L 8000:localhost:8000 -L 8765:localhost:8765 -N

This will set up the ability to use Rstudio on `localhost:8765` (log in as ubuntu with a password of rstudio), and any jupyter notebooks you may spawn on `localhost:8000`. This will persist until you disconnect from the internal Sanger network. Spawning jupyter notebooks is quite easy - SSH into the instance, open up your friend `screen -DR`, navigate to the folder of relevance and call the following (if you wish to use labs, just write `jupyter lab` instead of `jupyter notebook`):

	jupyter notebook --no-browser --port=8000

Copy the link that you get given, paste it into your browser and you're good to go. After the first time for a given notebook, you can go back to `localhost:8000`. Upon disconnecting from the Sanger internal network, you'll have to call `ssh -f` again to reestablish the link, plus close any open notebook tabs in your browser and launch a fresh `localhost:8000`. If you choose to instead follow the restart kernel prompt, you'll lose all your run information, as if you closed the notebook server entirely and loaded the notebook anew.

### Communicating with the farm and your computer

You can quite easily move stuff between the cloud and the farm or your computer as desired. You can SSH into the farm from your machine by typing out the full farm address:

	ssh <user-id>@farm3-login.internal.sanger.ac.uk

It's recommended to use `rsync` for moving files between the different systems as it automatically assesses file integrity via MD5 sums. The `-P` flag displays progress, and you can add an `r` to it if you need to copy a whole folder. Example syntax for farm-cloud communication while on the cloud, and cloud-computer communication while on your computer (also works if you reverse the components) would be:

	rsync -P <user-id>@farm3-login.internal.sanger.ac.uk:<path-on-farm> <path-on-cloud>
	rsync -P ubuntu@<floating-ip>:<path-on-cloud> <path-on-computer>

### Communicating with Google Drive

Sometimes you're working with someone who can't access the farm (or just isn't particularly farm-savvy), and you need to get stuff to Google Drive to share it with them. Basecloud comes with rclone baked in, which allows you to skip the step of downloading to your computer and then manually uploading from there. The [official write-up](https://rclone.org/drive/) is a bit daunting, the main things we need to learn how to do is set up the connection in the first place and copy things to/from the drive while on the instance.

* Write `rclone config`
* In the choice that comes up, write `n`
* Under `name`, write `remote`
* Find Google Drive in the list, it will almost certainly come with `"drive"` in the line below it. If so, write `drive`. If not, write whatever quoted string comes in the line below Google Drive.
* Skip `client_id` and `client_secret` (press enter twice)
* Under `scope`, write `1`
* Skip `root_folder_id` and `service_account_file` (press enter twice)
* Write `n` for editing the advanced config
* When asked about auto-config, write `n`. This will return a URL which you should paste into your browser and authorise rclone for Google Drive. Copy the resulting code and paste it back into the config script.
* Write `n` for team drive
* Write `y` to confirm the remote addition, and `q` to leave the config program

Once that's done, you'll be able to access your Google Drive via rclone, with it living under `remote:`. The main command will be `rclone copy`, which is similar in function to `rsync`.

	rclone copy <path-on-cloud> remote:<path-on-google-drive>
	rclone copy remote:<path-on-google-drive> <path-on-cloud>

Here's a script I wrote to automatically synchronise a number of folders to the Google Drive folder `Roser-Endometrium/endometrium` while automatically producing HTML renders of all existing jupyter notebooks. Only folders starting with the letter N are considered. Maybe the general ideas herein will be of use to someone?

	#!/bin/bash
	set -e

	for DIR in `ls | grep "^N"`
	do
		cd $DIR
		for FID in *.ipynb
		do
			jupyter nbconvert --to html $FID
		done
		cd ..
		rclone copy $DIR remote:/Roser-Endometrium/endometrium/$DIR
	done

### Snapshotting your instance

If you had to customise your instance quite heavily with additional programs or something of the sort, and recreating that would be difficult, you have the option of creating a snapshot of it. This way, all your configuration/setup gets preserved and you can automatically create a duplicate of the machine, just like you created a copy of the basecloud image to begin.

Assuming you've attached a volume, you'll need to detach it before the snapshotting and remove any knowledge of it from the instance's configuration files. To do that, connect to [Eta](http://eta.internal.sanger.ac.uk), go to the Volumes tab, press the little arrow in the far right of the entry for your volume and select Manage Attachments. Press Detach Volume twice. Now we just need to make a quick tweak on the machine, adjusting system records to forget the mount ever happened and rebooting the instance to make it correctly forget about the volume. You can skip executing this code snippet if you did not mount a volume. However, if you do not execute it but had one mounted, a newly created machine will go looking for a mounted volume, fail to find it and die, rendering your snapshot useless.

	sudo sed '/^\/dev\/vdb/ d' -i /etc/fstab
	sudo reboot & ( sleep 30; echo 'b' > /proc/sysrq-trigger )

Snapshotting is super easy - you go into Eta, and in the Instances tab you press the default Create Snapshot button that appears on the right of the record of your instance. Name the snapshot something informative, preferably including your user ID, a relevant project name or something of the sort, and press Create Snapshot. Once it finishes, you can re-attach your volume and find its contents unscathed. Just follow the instructions from earlier in the document in both Eta and the machine itself, skipping the `sudo mkfs.ext4` line as you don't need to create a file system.

### Deleting your instance

* Go into Eta, go to Compute, then Instances, press the little arrow in the right of the row of your instance record, Delete Instance, confirm with Delete Instance.
* If you wish to remove the associated volume (you might want to keep it, I've never kept one personally), go to the Volumes tab, then Volumes, press the little arrow in the right of the row of your volume record, Delete Volume, confirm with Delete Volume.
* If you set up the Rstudio/jupyter notebook SSH tunnel, call `ps aux | grep ssh` on your computer to identify the tunnel process. If you see an entry with a command that looks like the tunnel setup from this document, or whatever modifications you may have made to it, take note of the process ID in the second column of the results, and kill it with `kill -9 <id>`.
* Remove any host-specific SSH debris. The next time you try to connect to an instance with the same floating IP, SSH is going to get in the way as it'll have a recollection of a different machine under the same address. I just call `rm ~/.ssh/known_hosts`. If for whatever reason you're uncomfortable doing that, open the file in your text editor of choice and manually remove the line with details matching your deleted instance's floating IP.
