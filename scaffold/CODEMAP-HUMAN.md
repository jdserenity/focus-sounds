# Architecture (human-readable)

Compact human-readable overview of this project's system architecture and codebase. The maintainer likes diagrams and visual explainers. It should be written in the first person (I, me, my), never the second person.

Confirmed facts and decisions only. This is not a instruction manual for the app. This is for the maintainer to quickly understand the codebase at a high-level.

## Headphone auto-pause

If I'm playing focus audio on headphones or earbuds and I take them out (or disconnect Bluetooth), the app pauses so sound doesn't jump to my speakers. If I plug those headphones back in, it starts playing again — but only when the pause happened because of the disconnect. If I paused myself, reconnecting does nothing.

It treats wired jack headphones and Bluetooth/Bluetooth LE outputs as headphones. It does not try to guess USB speaker boxes vs USB headsets.

## AirPods / media controls

While Focus Sounds is playing (or paused with a sound still loaded), macOS treats it as the Now Playing app. That means the AirPods pause/play action and keyboard media keys control my focus audio instead of opening Apple Music.

## Global hotkey

I can set a keyboard shortcut (default Control+Option+Space) that toggles play/pause without opening the menu. The shortcut only works while Focus Sounds is running in the menu bar. I change it from the bottom row of the panel, between Quit and Delete sound.

## Smooth loops

When a track loops, the app crossfades the end into a fresh copy at the start (~2.5 seconds) so I do not hear a hard jump or click.
