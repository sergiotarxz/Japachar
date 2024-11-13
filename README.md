# Japachar

## Introduction

Japachar is an easy way to learn the basic Japanese characters (Hiragana and Katakana)

## Installation

The official way to install Japachar is to use the [Flathub packaging](https://flathub.org/apps/me.sergiotarxz.JapaChar)

Please follow the Flathub instructions for your operative system to install the
app.

## Contributing

### Writting docs

You are encouraged to make pull requests that only fix docs including typos.

### Filing issues

If you have a bug please share as much details about your distro as you
can including proccesor architecture and if you can the Japachar version.

### Native setup

* Ensure you have a complete Perl and build tools such as gcc, make, etc.

* Ensure you have libadwaita, sqlite3, gtk, glib, fontconfig and other gnome libraries development headers installed in your system. (If you get errors because of missing libraries search internet in what package you can find them in your operative system)

* Run `perl Build.PL` in the root of this repository.

* Run `perl Build installdeps` in the root of this repository.
Here you can find most of the possible setup problems, ask in the issues or official
Discord if you do not now how to solve them and maybe update the docs.

* Run `perl scripts/japchar.pl` you may find you still have missing dependencies, if you have success in this step the application will start.

### Flatpak setup

* `git clone https://github.com/flathub/me.sergiotarxz.JapaChar`

* `cd me.sergiotarxz.JapaChar`

* `sudo flatpak install org.gnome.Sdk//47`

* `sudo flatpak-builder build  --install --force-clean me.sergiotarxz.JapaChar.yml`

### Contact

You can find us in our [Discord community](https://discord.gg/qsvzSJPX), we understand using Discord is not acceptable for everybody, if you step up to moderate a parallel community in a more free platform we will help you as much as we can.
