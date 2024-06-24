# JapaChar

## Installing in Linux

Run these commands with flatpak correctly configured for your desktop
environment:

```shell
git clone https://git.owlcode.tech/sergiotarxz/JapaChar
cd JapaChar
flatpak-builder --repo=repo --user  build me.sergiotarxz.JapaChar.yml  --force-clean
flatpak --user remove me.sergiotarxz.JapaChar
flatpak --user install me.sergiotarxz.JapaChar
```
You should find the app installed for your desktop.
