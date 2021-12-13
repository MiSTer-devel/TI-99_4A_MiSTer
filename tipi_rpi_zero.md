# How to get TIPI on Raspberry PI Zero W working with MiSter via USER Port.
These instructions are how to modify a TIPI install to be used on a Raspberry PI Zero W with the MiSter's User Port.
This is NOT necessary for Raspberry PI 3 and above.

- SSH to Tipi
- Login with default username/password (tipi/tipi)
- cd /tipi/services/libtipi
- vi tipiports.c (or nano tipiports.c for the non-vi folks)
	- Goto line 55 (:55 in vi, CTRL- in Nano)
	- uncomment this line:
		  // delayMicroseconds(1L);
      to look like this:
		   delayMicroseconds(1L);
- Write/Save changes and exit (:wq in vi, CTRL-X, answer Y to save changes, press enter on filename to keep same filename)
- ./rebuild.sh
	- During build process, you'll see a bunch of warnings, it's safe to ignore them.
- sudo reboot

