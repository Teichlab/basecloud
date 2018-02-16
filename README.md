# Basic R/python Teichlab computational cloud

This bit of text is going to detail the process of creating a functional machine on the internal OpenStack cloud infrastructure, making use of a template pre-loaded with all sorts of computational goodies requested from all across the lab:

* **R/Rstudio:** edgeR, DESeq2, scater, scran, monocle, destiny, pcaMethods, zinbwave, tidyverse, devtools, Seurat, vcfR, igraph, car, cellrangerRkit, velocyto.R, EmptyDrops
* **python3:** scanpy, sklearn, jupyter, velocyto, snakemake, GPy, GPclust, GPflow
* **iRODS**
* **Docker**
* **Julia**
* **samtools, bcftools, biobambam2, bedtools**

If you don't see your preferred package on here, do not despair! A lot of the installed options come with a truckload of dependencies, so your everyday utility (ggplot2, numpy etc.) is here. And if it isn't here, you have the power to install more things within R/Rstudio, or via `sudo pip3` for python. There's also `apt-get` for more all-purpose stuff. The cloud does not come with mapping/genomics tools built in, those pipelines are supported by the second template mapcloud.

### Basic OpenStack things

* The Teichlab allocation on OpenStack was estimated for 10 active users with reasonable computational needs, assuming a `k1.2xlarge` instance per head with a 2TB volume to boot. As such, try not to use more than its resource total (28 cores, 227,000 MB RAM, 2TB volume space) at a time. If you do end up using more (dire computational straits happen), please free it up in a timely manner.
* Even when not extending past your bit of resources, try to keep your instance life to a minimum. I'm not saying kill off your cloud if you wait two hours between analyses, but if the machine has been sitting around idly for a month you should probably get rid of it. The templates come stocked with a lot of requested tools to make killing off your machines as painless as possible, as pretty much everything will be waiting for you when you make a new one. If you set up something particularly annoying that you don't want to do again, you can take a personalised snapshot of your cloud. I'll walk you through the steps later on in the document.
* Ideally, the volume storage should be mainly thought as space to let your analyses run and not an actual long-term storage option. You can quite easily copy data to/from the farm with `rsync`, once again I'll write how in a bit. I'd recommend saving all your analysis files to the mounted volumes as the built-in drive space of a lot of the cloud options is quite limited. Plus, you can theoretically swap volumes between machines, carrying the files across!
* `screen -DR` is your friend. This command opens up a screen that won't stop existing when you log out of your cloud. As such, you can call this command, launch your two-week analysis and disconnect, and it will still run. Once inside the screen, use `ctrl+a, ctrl+d` to exit. You can spawn extra screens with `ctrl+a, ctrl+c` and cycle through them with `ctrl+space`. Kill off any screens you don't need by typing `exit`. There's [a lot more](http://aperiodic.net/screen/quick_reference), but this is all I've needed so far.

### Getting onto Openstack

* In order to access the cloud, write servicedesk asking for an OpenStack account on tenant team205 (tenant is cloud slang for a group). If you intend to use iRODS from your machines, also ask to be switched to native iRODS authentication. They'll know what to do.
* Once your cloud account email arrives, follow the instructions to retrieve your password and save it somewhere. Do not change it!
* Go onto [Delta](http://delta.internal.sanger.ac.uk) and log in with your Sanger user name and the password you just saved.
* Open up a terminal. Set yourself to the user you intend to connect to the cloud as. Write `ls ~/.ssh`. If you don't see an `id_rsa.pub`file, [generate an SSH key](https://docs.joyent.com/public-cloud/getting-started/ssh-keys/generating-an-ssh-key-manually/manually-generating-your-ssh-key-in-mac-os-x).
* Write `cat ~/.ssh/id_rsa.pub` and copy the entirety of what comes out.
* Go to the Instances tab of [Delta](http://delta.internal.sanger.ac.uk). Press Launch Instance. Go to the Access & Security tab. Press the plus on the right hand side of the Key Pair dropdown. Paste in the bit you just copied. Name the key pair something informative, such as your Sanger user ID. Press Import Key Pair.
* Done! You can now access the website to create/manage your machines and volumes, and have set up SSH for connecting to the cloud from your computer.

### Creating a basic R/python machine from the image

* Log in to [Delta](http://delta.internal.sanger.ac.uk), go to the Instances tab, press Launch Instance.
* Name the instance something informative.
* The flavours are a dropdown of available resource allocations you can request. Pick anything `small` or higher, the template can't build on `tiny` as it's too big. If you need more than two cores to run something, by all means go for it!
* Under Instance Boot Source, select boot from snapshot. In the dropdown that appears, select `basecloud`.
* Switch over to the Access & Security tab. In the Key Pair dropdown, select the key pair you imported earlier. In the checkboxes below, check `default`, `cloudforms_ssh_in` and `cloudforms_icmp_in`.
* Switch over to the Networking tab. Ensure that `cloudforms_network` is dragged into the selected networks. Press launch.
* While you wait for the machine to appear, switch to the Volumes tab. Press Create volume. Name the volume something informative, I usually just have it match the instance name. Enter a size in GB. Press Create Volume.
* Go back to the Instances tab. Once the machine spawns, press the little arrow in the right of the screen for your instance's entry and select Associate Floating IP. Pick one from the dropdown. Tomas's suggestion to stick to the same one is not a bad idea! Go back to the Volumes tab. Press the little arrow in the right of the screen for your volume's entry and select Manage Attachments. Pick your machine in the dropdown. Press Attach Volume.
* Done! You just created an instance and attached a volume to it. You can now connect to it via `ssh ubuntu@<floating-ip>`. Just a small bit of setup before you're all ready to go!

### SSH configuration

If you foresee yourself keeping an instance around for a long time (heavy computations happen!) or re-using the same floating IP, as per Tomas's suggestion, you can create an SSH configuration file to store the information for you. Open `~/.ssh/config` in your preferred text editor and add the following bit:

	Host <your-chosen-name>
		HostName <floating-ip>
		User ubuntu

Now you can just SSH or `rsync` with the cloud just by specifying the name you chose instead of the full `ubuntu@<floating-ip>` syntax!

### Machine-side setup

Once you SSH into the machine, you need to mount the volume you created. The following code chunk creates a file system on the drive space provided (skip if you're reattaching a volume you already used in another instance), mounts it, tweaks an internal configuration file to acknowledge its existence, makes you (ubuntu) the owner and then quickly "jogs" it to see that it works. In the summer of 2017, sometimes the volumes would spawn wrong and would hang the moment they were asked to do anything borderline resembling saving files, so the precautionary measure has been kept in place as a diagnostic tool.

	sudo mkfs.ext4 /dev/vdb
	sudo mount /dev/vdb /mnt
	sudo sed 's/data1/mnt/g' -i /etc/fstab
	sudo chown -R ubuntu: /mnt
	cd /mnt && dd if=/dev/zero of=deleteme oflag=direct bs=1M count=1024 && rm deleteme

If you intend to work with Rstudio, you'll need to setup login credentials for your user, i.e. ubuntu. To do this, call the following line and enter rstudio as your password, re-entering it immediately thereafter:

	sudo passwd ubuntu

There's a bit of setup required if you intend to use iRODS. You need to grab your configuration from the farm, and then edit it to remove some farm-specific location information in `irods_environment.json`. You then need to tell a bit of internal cloud configuration to properly use iRODS by including `internal.sanger.ac.uk` and reboot the machine for the change to go into effect. Once you SSH back in, type `iinit` and give it your iRODS password. Done! Once again, all this is handled by a code snippet (you'll likely need to call the `rsync` alone and then you can paste the rest):

	rsync -Pr <user-id>@farm3-login.internal.sanger.ac.uk:~/.irods ~
	sed ':a;N;$!ba;s/,\n    "irods_plugins_home" : "\/opt\/renci\/icommands\/plugins\/"//g' -i ~/.irods/irods_environment.json
	echo 'supersede domain-name "internal.sanger.ac.uk";' | sudo tee -a /etc/dhcp/dhclient.conf
	sudo dhclient -r
	sudo reboot & ( sleep 30; echo 'b' > /proc/sysrq-trigger )

And with that, you're good to go! Make use of a number of popular R/python packages, some basic utility like samtools, connect to Rstudio/jupyter notebooks remotely! Oh wait, how do I do that?

### Using Rstudio/jupyter notebooks

If you intend to use your machine for Rstudio/jupyter notebooks from the comfort of your own computer, call the following command in your terminal:

	ssh -f ubuntu@<floating-ip> -L 8000:localhost:8000 -L 8765:localhost:8765 -N

This will set up the ability to use Rstudio on `localhost:8765` (log in as ubuntu with a password of rstudio), and any jupyter notebooks you may spawn on `localhost:8000`. This will persist until you disconnect from the internal Sanger network, and you'll have to call `ssh -f` again to reestablish the link if you lose connection. Spawning jupyter notebooks is quite easy - open up your friend `screen -DR`, navigate to the folder of relevance and call the following:

	jupyter notebook --no-browser --port=8000

Copy the link that you get given, paste it into your browser and you're good to go. After the first time for a given notebook, you can go back to `localhost:8000`.

### Communicating with the farm and your computer

You can quite easily move stuff between the cloud and the farm or your computer as desired. You can SSH into the farm from your machine by typing out the full farm address:

	ssh <user-id>@farm3-login.internal.sanger.ac.uk

It's recommended to use `rsync` for moving files between the different systems as it automatically assesses file integrity via MD5 sums. The `-P` flag displays progress, and you can add an `r` to it if you need to copy a whole folder. Example syntax for farm-cloud communication while on the cloud, and cloud-computer communication while on your computer (also works if you reverse the components) would be:

	rsync -P <user-id>@farm3-login.internal.sanger.ac.uk:<path-on-farm> <path-on-cloud>
	rsync -P ubuntu@<floating-ip>:<path-on-cloud> <path-on-computer>

### Snapshotting your instance

If you had to customise your instance quite heavily with additional programs or something of the sort, and recreating that would be difficult, you have the option of creating a snapshot of it. This way, all your configuration/setup gets preserved and you can automatically create a duplicate of the machine, just like you created a copy of the basecloud image to begin.

The first thing you need to do is ensure that your volume is detached. We don't want to be snapshotting that, we just want the software and stuff on the main part of the cloud. To do that, connect to [Delta](http://delta.internal.sanger.ac.uk), go to the Volumes tab, press the little arrow in the far right of the entry for your volume and select Manage Attachments. Press Detach Volume twice. Now we just need to make a quick adjustment on the machine, adjusting system records to forget the mount ever happened and rebooting the instance to make it correctly forget about the volume.

You'll need to run the `sed` below before snapshotting regardless of whether you've actually attached a volume to your machine or not, though. However, you can skip the reboot. Otherwise a newly created machine will go looking for a mounted volume, fail to find it and die. This particular file gets rewritten when a new instance gets spawned, making it irrelevant if you've actually attached a volume or not.

	sudo sed 's/\/dev\/vdb/#\/dev\/vdb/g' -i /etc/fstab
	sudo reboot & ( sleep 30; echo 'b' > /proc/sysrq-trigger )

Snapshotting is super easy - you go into Delta, and in the Instances tab you press the default Create Snapshot button that appears on the right of the record of your instance. Name the snapshot something informative, preferably including your user ID, a relevant project name or something of the sort, and press Create Snapshot. Once it finishes, you can re-attach your volume and find its contents unscathed. Just follow the instructions from earlier in the document in both Delta and the machine itself, skipping the `sudo mkfs.ext4` line as you don't need to create a file system.

### Deleting your instance

* Go into Delta, go to Instances, press the little arrow in the right of the row of your instance record, Terminate Instance, confirm with Terminate Instance.
* If you wish to remove the associated volume (you might want to keep it, I've never kept one personally), go to the Volumes tab, press the little arrow in the right of the row of your volume record, Delete Volume, confirm with Delete Volume.
* If you set up the Rstudio/jupyter notebook SSH tunnel, check whether it's active by calling `ps -a | grep ssh` on your computer. If you see an entry with a command that looks like the tunnel setup from this document, or whatever modifications you may have made to it, take note of the process ID in the first column of the results, and kill it with `kill -9 <id>`.
* Remove any host-specific SSH debris. The next time you try to connect to an instance with the same floating IP, SSH is going to get in the way as it'll have a recollection of a different machine under the same address. I just call `rm ~/.ssh/known_hosts`. If for whatever reason you're uncomfortable doing that, open the file in your text editor of choice and manually remove the line with details matching your deleted instance's floating IP.
