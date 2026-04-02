## Challenge 1: Network Debugging

We spend a lot of time in Linux network plumbing. Linux networking has gotten deceptively complicated. We want to make sure you’re comfortable diving into a misconfiguration and figuring out what’s gone wrong. You should be comfortable with iproute2, network sysctls, relatively low-level TCP/IP, and WireGuard.

For this, we've built a system that'll be run in two apps: a simple HTTP server and a client that makes requests to it. The network is broken. Unbreak it!

### Fixing the Glitch

At this point you have two apps that are configured incorrectly. The client is talking directly to the server over the private network (6pn). This is what you'd normally want to do on ****, but this is a hiring challenge so we're going to do it the weird way. What we want is for the client to talk to the server using a WireGuard tunnel, which is set up (badly) on both instances.

There's a `test-connection.sh` script that tries to connect to the server from the client first over 6pn, and then over wireguard. The end result should be that connections over 6pn should be blocked, and connections over wireguard should work. The opposite is the case right now. The test script is only present on the client machine since you don't need to make it work in the other direction.

You are free to modify and install any tools you think might be required. Please make notes about what you've done and all of the stupid places we've broken stuff.
The 6pn addresses for this are the `[fdaa::]` addresses on `eth0` in each vm.
WireGuard should be running over 6pn, using the `fdaa` addresses. That's fine! It's what we want. We just don't want to use the 6pn addresses directly for HTTP; we want to route them over a WireGuard connection running over our 6pn addresses.

Since what we're actually trying to do here is pretty simple, you might be tempted to simply reconfigure the applications and redeploy them from scratch with a known-good configuration. Do not succumb to this temptation! You have to fix our dumb configuration in the running VM.

There are at least 7 things wrong with these VMs. See how many issues you can find.

Once you cleaned up the mess we left you, write up a list of what you fixed, how you fixed and any additional thoughts in your notes.



## Challenge 2: Storage Debugging

Operating a large fleet of servers and VMs is part of the job and we provide block storage for our users. We want you to be familiar with LVM, device mapper, filesystems, and linux storage systems so we put together a little challenge to help us fix a hypothetical storage problem on one of our servers.

### Challenge Instructions

The machine runs a really simple web service that serves objects out of a directory. Feel free to check it out by running something like `curl http://localhost:8000`, but the objective is really just to approximate a production service that relies on some disk storage.

We're pretending we have real disks in our LVM pool by using loopback devices on top of files in the `/media` directory. We're just creating them with [`fallocate -l 1800M /media/diskN.img`](https://man7.org/linux/man-pages/man1/fallocate.1.html) as 1800MB images.

```
root@6e82dd90c22398:/# ls -lh /media/disk0.img
-rw-r--r--  1 root root 1887436800 Aug 23 17:05 disk0.img
```

We ran out of space so we created a few more "disks" and added them to the pool so now there are 3, but things still aren't working quite right. Then we asked ChatGPT for help and are pretty certain we've managed to break things even more. So we need your help getting things healthy again, and helping ensure we don't run out of disk space as more data is created.

The objective:

1. Fix up the **existing** `/data` volume so it's usable.
2. Set up the `vg0` VG with four 1800MB disks, using loopback images.
3. Expand the `data0` LV to 4GB.
4. Write a tiny bit of software to automatically expand the volume by 500M any time it gets close to full.

On the host is a script that will help you test things as you make progress. You can run `test-storage.sh` and it will run some simple tests to ensure things are working.

Feel free to install tools you think might be required and change things around, but please keep notes about what you've done. Also write down any silly things you find that are broken. If you manage to break things irreparably, then you can just stop the machine, delete it, and create a new one. Keep a note if that happens so we know where things went sideways. We've broken things in production plenty of times and are more interested in how you solve problems.

Oh! And one more thing. You might be tempted to use **** Volumes to solve this challenge. Resist the temptation! **** Volumes are pretty cool, but we don't have network attached block storage on our physical servers so this is an actual constraint.

Try to pretend like this is a production system and minimize any downtime on the HTTP object service. The notes you're keeping are the sort of raw context we'd want to have if we were doing a retrospective after an outage.

Have fun!