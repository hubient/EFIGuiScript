# EFIGuiScript

## Desctiption

The script is build on a openSUSE Thumbleweed with KDE running.

It's possible it runs also on other window manager like gnome.
The script helps you to choos easy from desktop to choose on a UEFI System the next boot and the standad boot system.

## Dependencies 

I run it with the following tools it can run also with other versions but it's not tested with it-
ksh         - as script language version (AT&T Research) 93u+ 2012-08-01
efimanager  - version 14
zenity      - release 3.2

## Recomandation for running it

You should prepera a sudoer entrie in /etc/sudoers life follow
<user> ALL = (root) NOPASSWD:/usr/sbin/efibootmgr
  
where <user> is your loggin user.
 
 The script calls "sudo /usr/bin/efibootmgr" to set and read the option.
 
### Open for improvements
 
actual the reboot event is given only of a kde desktop is available you can cancel it how you can do it under kde regulry.
as i don't have actual a gnome system i could not test a version working for gnome
 
If you know some userfull extension please make a sugestion 
