# How to get TIPI on Raspberry PI Zero W working with MiSter via USER Port.
These instructions are how to adjust a TIPI install to be used on a Raspberry PI Zero W with the MiSter's User Port.
This is NOT necessary for Raspberry PI 3 and above.

- SSH to Tipi
- Login with default username/password (tipi/tipi)
- For this to work, you must be on Tipi version 2.31.  To update to 2.31, you'll either have to do it via ssh and the command line or temporarly use a Raspberry PI 3 or above to access TIPI from the TI-99/4A (call tipi) and perform an update.
  - For manual update via SSH :
    - `cd /home/tipi/tipi`
    - `git pull`
    - `cd /home/tipi`
- `vi tipi.config` (or `nano tipi.config` for the non-vi folks)
  - Goto the bottom of the file (`:$` in vi)
  - Add this line: (To add a new line at EOF in vi type `:A` then press enter)   
      `TIPI_SIG_DELAY=100`  
- Write/Save changes and exit (`:wq` in vi, `CTRL+X,` answer `Y` to save changes, press `Enter` on filename to keep same filename)
- `sudo reboot`

