# #255 Curated Updates

**Published on This Week in GNOME:** [https://thisweek.gnome.org/posts/2026/06/twig-255/](https://thisweek.gnome.org/posts/2026/06/twig-255/)

---


Update on what happened across the GNOME project in the week from June 19 to June 26.

## Third Party Projects

[Alexander Vanhee](https://matrix.to/#@alexandervanhee:matrix.org) reports

>
> I have overhauled Bazaar’s curated page. Vendors, such as distributions, can now make use of several widget types to showcase the apps they want to promote to their users.
> One of these widgets displays articles, which can be used to recommend apps or share general news about the OS in a place where users will naturally discover them.
>
> (The data shown is only for illustrative purposes.)
>
>
>
>
>

![Image](https://thisweek.gnome.org/_astro/qlqFbeMhgJEvxMUMJTeyibYE_bazaar-1-curated-page.BYLSZy7U_Z1LWzeI.webp)

>
>

![Image](https://thisweek.gnome.org/_astro/hiGQPfNBaWWuHomaBXKywKyF_bazaar-2-article-page.C6Bu_qUQ_1uCtFn.webp)

>
>

![Image](https://thisweek.gnome.org/_astro/tcGbwwwvMVeyGrcLeauDFALb_bazaar-3-app-in-article.DCqHR3C8_ZpquCF.webp)

>

[jjjjjj0](https://matrix.to/#@jjjjjj0:matrix.org) reports

>
> I published last week the first release of [EdiTidE](https://editide.frama.io/).
>
> It’s a simple source-code editor, something between the GNOME Text Editor
> and GNOME Builder. Think of it as an alternative to Notepad++ in terms of features.
>
> It works fully sandboxed, and is quite convenient to quickly open a project and browse the code in.
>
> It has a bunch of settings for customization (like for replacing the menubar by a hamburger button, to make it more GNOME-ish), and can be enhanced with extensions (in Python).
>
> [Get it on Flathub](https://flathub.org/en/apps/io.frama.editide.editide)
> [Contribute to translations](https://hosted.weblate.org/engage/editide/)
>
>
>

![Image](https://thisweek.gnome.org/_astro/WHzabYbPJEgajDhYtVPWWdWn_editide-light.Wq6iSDMH_kTtoi.webp)

>

[Tanay Bhomia](https://matrix.to/#@tanaybhomia:matrix.org) reports

>
> Whisp Update: Smart Text Expansions, 4k Downloads, & Donations!
>
> Whisp just crossed 4,000 downloads on Flathub! Thank you all for the incredible support. Donations are officially live! If Whisp helps your workflow, you can now support its solo student development via Ko-fi or GitHub Sponsors on the website.
>
> In v1.3.4, we’ve also added a major new feature to remove friction from your workflow: Smart Text Expansions.
>
> Typing :: anywhere in a note now opens a lightning-fast, completely keyboard-navigable GTK popover to instantly insert dynamic data:
>
> ::today / ::date(5) for dynamically calculated dates.
> ::roll(d20) for D&D dice rolls.
> ::random(str, 20) for instant secure passwords or placeholder text.
>
> Links: [https://flathub.org/en/apps/io.github.tanaybhomia.Whisp](https://flathub.org/en/apps/io.github.tanaybhomia.Whisp) | [https://github.com/tanaybhomia](https://github.com/tanaybhomia) | [https://tanaybhomia.github.io/Whisp/](https://tanaybhomia.github.io/Whisp/)
>
>
>
>
>

[Sjoerd Stendahl](https://matrix.to/#@sjoerdb93:matrix.org) announces

>
> This week I’ve released several updates to Lockpicker, a new tool to recover passwords from their hash. The most obvious change is that the console-output has been replaced by friendly widgets, giving a much more convenient overview. The status overview also spots a progress bar to see how many candidates have been tested. And the ordering of the sidebar should be more intuitive. The logo has also been updated to look a bit more proper for now.
>
> Lockpicker now also has support for sessions. You can pause a session, or run multiple in parallel. Sessions persist over reboots, so you can pick up any time it’s convenient. Finally word lists and rules can now imported into the application, and be chosen from a dropdown menu.
>
> Get it on Flathub [here!](https://flathub.org/en/apps/se.sjoerd.lockpicker)
>
>
>

![Image](https://thisweek.gnome.org/_astro/IUWGVfvbMmKrpAJesKhqMUgU_image.BDv3bsgM_Zh0RC9.webp)

>

[francescocaracciolo](https://matrix.to/#@francescocaracciolo:tchncs.de) announces

>
> Newelle (AI assistant and agent for Gnome) updated to 1.4.5
>
> This new release features:
>
> 🖼 Image generation support (supporting an integrated stablediffusion instance or cloud models)
>
> 💬 New chat redesign: a more minimal and space efficient layout
>
> 🐞 Minor improvements like support for STDIO MCP Servers
>
> Get it on [Flathub](https://flathub.org/apps/details/io.github.qwersyk.Newelle)
>
>
>
>
>

![Image](https://thisweek.gnome.org/_astro/e373e7ded079c73e48da3045f9f1a20f6b022b3d2070471302170279936_1000063438.BJnYlRf0_2r8cpy.webp)

>
>

![Image](https://thisweek.gnome.org/_astro/905c0a5672c43767ea4e365685b1b3ddb5ec4aac2070471304254849024_1000063439.1fDzN01Z_zqrKw.webp)

>
>

![Image](https://thisweek.gnome.org/_astro/6a4860bf52d9b25f116177985c4f5a2275c27f502070471299741777920_1000063437.B4IvpPia_12VdEC.webp)

>

[Anton Isaiev](https://matrix.to/#@totoshko88:matrix.org) announces

>
> RustConn 0.17 Released
>
> This is the first release since RustConn turned one, and it landed just two weeks after 0.16. Despite the long feature list, the goal hasn’t changed: RustConn is still a simple address book and orchestration layer over your connections, nothing more.
>
> The headline this cycle is Workspaces. With a dozen sessions open across split panes, you can now save the whole set as a named workspace and reopen it in one click - every connection, tab order, split layout, and tab group restored. Reboot the laptop, come back, and your working set is exactly where you left it. No more leaning on clusters and re-clicking reconnect.
>
> A few other highlights, mostly user requests:
>

>
* Simple Sync - opt-in bidirectional sync of connections, groups, templates, and snippets across devices. Passwords stay in each device’s keyring, never in the sync file.
>
* Native PKCS#11 / YubiKey SSH auth - hardware-token keys offered directly, no SSH-agent workaround, works through jump hosts too.
>
* Built-in port knocking and fwknop SPA - open a firewall before connecting, pure-Rust, no external CLI.
>
* Security hardening - clipboard auto-clear, SSH passwords zeroized from memory, and a couple of command-injection paths closed off.
> Homepage: [https://github.com/totoshko88/RustConn](https://github.com/totoshko88/RustConn)
> Flathub: [https://flathub.org/apps/io.github.totoshko88.RustConn](https://flathub.org/apps/io.github.totoshko88.RustConn)
> Snap: [https://snapcraft.io/rustconn](https://snapcraft.io/rustconn)
>
>

>
>

![Image](https://thisweek.gnome.org/_astro/mSuajmWqOKbXkSuXWUMywnnR_rustconn.i0BsI7mU_Hz9yc.webp)

>

### Gitte [↗](https://codeberg.org/ckruse/Gitte)

A simple Git GUI for GNOME

[Christian](https://matrix.to/#@christian:kruse.cool) says

>
> Gitte, a simple Git client for GNOME built with GTK4, libadwaita and Relm4, just got its 0.8.0 release! 🎉
>
> The headline feature this time is cherry-picking: you can now grab one or more commits straight from the commit log and apply them onto your current branch. Diffs also learned to handle the awkward cases gracefully. Binary files and overly large diffs are now clearly marked as such across all diff views, and there’s a new “filtered files” option that lets you configure paths which are treated like binary files and kept out of diffs. In the working copy view you can filter what’s shown to new, tracked or all files.
>
> You also get more space when you need it: you can maximize the diff view with `Ctrl+M`, and in the commit graph that shortcut cycles between maximizing the graph, the diff and the normal layout.
>
> A few new things can now be configured per repository: you can set merge-/pull-request and issue URLs manually for each one, and pick a default location for new and cloned repositories (thanks to René Fouquet!).
>
> On the UI side, the revert dialog and the commit detail box got an overhaul.
>
> And of course there’s the usual pile of fixes: bad SSH-signed commits are now shown as bad instead of “key unavailable”, commit messages now conform to the Git specification, and signature verification finally works under Flatpak, where the verification temp file is now written to a path that’s also reachable from the host.
>
> Under the hood there’s a fresh Chinese (zh_CN) translation (thanks to Dawnchan030920), new `just` / `bacon` developer commands including recipes to build and run as a Flatpak (thanks to Bahrom Magdiyev), and the Nix flake can now build and run Gitte directly with `nix build` / `nix run` (thanks to bitSheriff).
>
> Get it on [Flathub](https://flathub.org/apps/de.wwwtech.gitte), [for macOS](https://gitlab.com/dehesselle/gitte_macos/-/releases/v0.8.1+51) or [have a look at the Code](https://codeberg.org/ckruse/Gitte).
>
>
>
>

![Image](https://thisweek.gnome.org/_astro/MmtWIBRfMmsyTIGKMFKoNSVU_gitte-maximized-commit-log.CjxOS13i_x9QIJ.webp)

>
>

![Image](https://thisweek.gnome.org/_astro/hJTxxurQXOWOYIKhZTjHYmwm_gitte-cherry-pick.UonOzqjU_Z26SvG9.webp)

>

### Gir.Core [↗](https://gircore.github.io/)

Gir.Core is a project which aims to provide C# bindings for different GObject based libraries.

[Marcel Tiede](https://matrix.to/#@badcel:matrix.org) reports

>
> New [GirCore](https://gircore.github.io/)  C# bindings got released in version [0.8.0](https://github.com/gircore/gir.core/releases/tag/0.8.0). The most prominent feature is GTK-Template support which required some breaking changes. Please read the release announcement for details. Further changes included support for GNOME SDK 50, several under the hood fixes and improvements to make working with GirCore easier.
>

### Bouncer [↗](https://github.com/justinrdonnelly/bouncer)

Bouncer is an application to help you choose the correct firewall zone for wireless connections.

[justinrdonnelly](https://matrix.to/#@justinrdonnelly:matrix.org) reports

>
> Bouncer 50.1.0 is here, and it’s a big one!
>
> Thanks to user submissions, this release includes new and updated translations and improved accessibility. There are also some subtle bug fixes alongside some more noticeable new features.
>
> Bouncer now uses more modern Adwaita widgets throughout, replacing basic labels and buttons for a more polished look and feel. The dashboard has also been redesigned as a tabbed interface, with a new Networks tab where you can change the firewall zone for a saved network or make Bouncer’s forget it altogether.
>
> As always, Bouncer is available on [Flathub](https://flathub.org/apps/io.github.justinrdonnelly.bouncer)!
>
>
>
>
>

![Image](https://thisweek.gnome.org/_astro/nTYgeoUmZaWfahMWDveyeEjK_bouncer-dependencies-light.Di1934w5_1baleS.webp)

>
>

![Image](https://thisweek.gnome.org/_astro/ZBmHUTmizKSWOwXXdFBUgQBt_bouncer-networks-light.CwF-mxTD_Zim5Tb.webp)

>
>

![Image](https://thisweek.gnome.org/_astro/lTkIYnWtwnsSesRnPegsoJYa_bouncer-choose-zone-light.-KDJwr2V_ZfuPwk.webp)

>

## Shell Extensions

[Christian W](https://matrix.to/#@cwittenberg:matrix.org) reports

>
> On the road a lot of frequently use VPNs? Show External IP extension does what it says and displays your external IP in the Toolbar, including Country flag. It sends a system notification if your IP has changed. Shows also IP history with Export and an image of the approximate location.
>
> This extension is handy for those who work at different locations or with different VPNs to quickly see your public IP and country.
>
> Search for “Show External IP” in Extension Manager
> Download here: [https://extensions.gnome.org/extension/5368/show-external-ip-thisipcancyou/](https://extensions.gnome.org/extension/5368/show-external-ip-thisipcancyou/)
> Github: [https://github.com/cwittenberg/thisipcan.cyou](https://github.com/cwittenberg/thisipcan.cyou)
>
>
>
>

![Image](https://thisweek.gnome.org/_astro/kfTlQqoipivVTFuueoUOqbmX_animated-gif-show-external-ip.Ds63KnZT_Z1ohf3f.webp)

>
>

![Image](https://thisweek.gnome.org/_astro/uwNWEgsbrLdxVsyilLEbWTyX_image.bik4Om7z_Z2v1hx4.webp)

>

[Aryan K](https://matrix.to/#@funinkina:matrix.org) announces

>
> Medialine is a GNOME Shell extension that shows your currently playing media right in the top bar, in a minimal and elegant way.
>
> It detects any MPRIS-compatible player (Spotify, Chrome and even PWAs) and displays the track inline in the panel. Click the indicator to open a rich popup with album art, a live seekable progress bar, and full playback controls — shuffle, previous, play/pause, next, and repeat. Supports multiple playing media in a compact view.
>
> The highlight is basically the support for PWA, it properly recognises the PWA icons and opens the correct window when clicked. Also has dynamic background color for the pop-up, based on the album art of the playing media.
>
> Get it today from: [https://extensions.gnome.org/extension/10076/medialine/](https://extensions.gnome.org/extension/10076/medialine/)
> Homepage: [https://github.com/funinkina/medialine](https://github.com/funinkina/medialine)
>
>
>

![Image](https://thisweek.gnome.org/_astro/qXcyBUjmDoCGttUPltaUVVfW_Frame44.HsUj2tO0_ZN3B1q.webp)

>

## Miscellaneous

[Evangelos “GeopJr” Paterakis 🏳️‍⚧️🏳️‍🌈](https://matrix.to/#@geopjr:gnome.org) reports

>
> This week I launched [a small unofficial website](https://gtk4android.geopjr.dev/) to share a few demo test builds of some GTK, Granite and libadwaita apps on Android. Give them a try!
>

## That’s all for this week!

See you next week, and be sure to stop by [#thisweek:gnome.org](https://matrix.to/#/#thisweek:gnome.org) with updates on your own projects!
