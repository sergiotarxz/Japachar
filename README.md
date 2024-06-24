# JapaChar

## Installing in Linux

Run these commands with flatpak correctly configured for your desktop
environment with flathub support:

```shell
flatpak --user install org.gnome.Platform//46
flatpak --user install org.gnome.Sdk//46
git clone https://git.owlcode.tech/sergiotarxz/JapaChar
cd JapaChar
# Ignore possible errors in the next command 
# if you do not have JapaChar installed.
flatpak --user remove me.sergiotarxz.JapaChar
flatpak-builder --install --user  build me.sergiotarxz.JapaChar.yml  --force-clean
```
You should find the app installed for your desktop.
