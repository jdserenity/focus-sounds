# Architecture (human-readable)

Compact human-readable overview of this project's system architecture and codebase. The maintainer likes diagrams and visual explainers. It should be written in the first person (I, me, my), never the second person.

Confirmed facts and decisions only. This is not a instruction manual for the app. This is for the maintainer to quickly understand the codebase at a high-level.

## Headphone auto-pause

If I'm playing focus audio on headphones or earbuds and I take them out (or disconnect Bluetooth), the app pauses so sound doesn't jump to my speakers. If I plug those headphones back in, it starts playing again — but only when the pause happened because of the disconnect. If I paused myself, reconnecting does nothing.

It treats wired jack headphones and Bluetooth/Bluetooth LE outputs as headphones. It does not try to guess USB speaker boxes vs USB headsets.
