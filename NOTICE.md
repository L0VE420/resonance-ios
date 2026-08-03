# Notices

Resonance is a derivative work informed by and, for selected networking/lyrics/player-solver behavior, translated from:

- **Echo Music** — <https://github.com/EchoMusicApp/Echo-Music>
- Pinned source revision: `35ad20446c6947900b57a20669a92281e6bbb73b`
- Copyright belongs to the Echo Music contributors.
- Licensed under the GNU General Public License, version 3.

Bundled files under `Resonance/Resources/Player/` originate from the pinned Echo Music revision unless a file states otherwise. Their original notices and GPL-3.0 terms are preserved by this project.

Imported resource SHA-256 values:

- `player_configs.json`: `D4250AFAD7D8E81D1A0F66B05B68A07D29B671B0BE7E972754F0C70549F773FA`
- `player_dates.json`: `3B17DA7AC381E4BDFDDEEA9791ABD9BE74756FDB76EDB8E2316BC490996025EB`
- `solver/astring.js`: `0C479B5D1AD846BDF05CC9A0F1A6C746E7B342F33A125759B51B9004628098A7`
- `solver/meriyah.js`: `B5880DED197F47D48828EC9E768B75836EAEE3A5DD3A042227B591FC8AB5551A`
- `solver/yt.solver.core.js`: `9146FA6A655EC35048F7D28F284BDC2CDCCD2C7B41F3A56860584C94A259C3C9`

The solver was reviewed before integration. It parses a downloaded YouTube player script and evaluates only the generated transform functions inside the app's isolated `JavaScriptCore` context; it contains no network or native-process access of its own.

Echo, YouTube, YouTube Music, Spotify, Apple, and other product names are trademarks of their respective owners. The temporary Resonance identity is not endorsed by those projects or companies.
