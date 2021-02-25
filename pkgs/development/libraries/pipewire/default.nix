{ stdenv
, lib
, fetchFromGitLab
, fetchpatch
, removeReferencesTo
, meson
, ninja
, systemd
, pkg-config
, doxygen
, graphviz
, valgrind
, glib
, dbus
, alsaLib
, libjack2
, udev
, libva
, libsndfile
, SDL2
, vulkan-headers
, vulkan-loader
, ncurses
, makeFontsConf
, callPackage
, nixosTests
, withMediaSession ? true
, gstreamerSupport ? true, gst_all_1 ? null
, ffmpegSupport ? true, ffmpeg ? null
, bluezSupport ? true, bluez ? null, sbc ? null, libopenaptx ? null, ldacbt ? null, fdk_aac ? null
, nativeHspSupport ? true
, nativeHfpSupport ? true
, ofonoSupport ? true
, hsphfpdSupport ? true
}:

let
  fontsConf = makeFontsConf {
    fontDirectories = [];
  };

  mesonBool = b: if b then "true" else "false";

  self = stdenv.mkDerivation rec {
    pname = "pipewire";
    version = "0.3.22";

    outputs = [
      "out"
      "lib"
      "pulse"
      "jack"
      "dev"
      "doc"
      "mediaSession"
      "installedTests"
    ];

    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "pipewire";
      repo = "pipewire";
      rev = version;
      hash = "sha256:6SEOUivyehccVR5zt79Qw2rjN2KcO5x3TEejXVxRlvs=";
    };

    patches = [
      # Break up a dependency cycle between outputs.
      ./alsa-profiles-use-libdir.patch
      # Move installed tests into their own output.
      ./installed-tests-path.patch
      # Change the path of the pipewire-pulse binary in the service definition.
      ./pipewire-pulse-path.patch
      # Add flag to specify configuration directory (different from the installation directory).
      ./pipewire-config-dir.patch

      # Various quality of life improvements that didn't make it into 0.3.22
      ./patches-0.3.22/0001-bluez5-include-a2dp-codec-profiles-in-route-profiles.patch
      ./patches-0.3.22/0001-pulse-server-don-t-use-the-pending_sample-after-free.patch
      ./patches-0.3.22/0005-fix-some-warnings.patch
      ./patches-0.3.22/0006-spa-escape-double-quotes.patch
      ./patches-0.3.22/0009-bluez5-volumes-need-to-be-distributed-to-all-channel.patch
      ./patches-0.3.22/0010-bluez5-set-the-right-volumes-on-the-node.patch
      ./patches-0.3.22/0011-bluez5-backend-native-Check-volume-values.patch
      ./patches-0.3.22/0012-media-session-don-t-switch-to-pro-audio-by-default.patch
      ./patches-0.3.22/0013-audioconvert-keep-better-track-of-param-changes.patch
      ./patches-0.3.22/0018-pulse-server-print-encoding-name-in-format_info.patch
      ./patches-0.3.22/0019-pulse-server-handle-unsupported-formats.patch
      ./patches-0.3.22/0021-jack-handle-client-init-error-with-EIO.patch
      ./patches-0.3.22/0022-pw-cli-always-output-to-stdout.patch
      ./patches-0.3.22/0024-policy-node-don-t-crash-without-metadata.patch
      ./patches-0.3.22/0025-bluez5-route-shouldn-t-list-a2dp-profiles-when-not-c.patch
      ./patches-0.3.22/0027-jack-apply-PIPEWIRE_PROPS-after-reading-config.patch
      ./patches-0.3.22/0038-jack-add-config-option-to-shorten-and-filter-names.patch
      ./patches-0.3.22/0046-jack-fix-names-of-our-ports.patch
    ];

    nativeBuildInputs = [
      doxygen
      graphviz
      meson
      ninja
      pkg-config
    ];

    buildInputs = [
      alsaLib
      dbus
      glib
      libjack2
      libsndfile
      ncurses
      udev
      vulkan-headers
      vulkan-loader
      valgrind
      SDL2
      systemd
    ] ++ lib.optionals gstreamerSupport [ gst_all_1.gst-plugins-base gst_all_1.gstreamer ]
    ++ lib.optional ffmpegSupport ffmpeg
    ++ lib.optionals bluezSupport [ bluez libopenaptx ldacbt sbc fdk_aac ];

    mesonFlags = [
      "-Ddocs=true"
      "-Dman=false" # we don't have xmltoman
      "-Dexamples=${mesonBool withMediaSession}" # only needed for `pipewire-media-session`
      "-Dudevrulesdir=lib/udev/rules.d"
      "-Dinstalled_tests=true"
      "-Dinstalled_test_prefix=${placeholder "installedTests"}"
      "-Dpipewire_pulse_prefix=${placeholder "pulse"}"
      "-Dlibjack-path=${placeholder "jack"}/lib"
      "-Dgstreamer=${mesonBool gstreamerSupport}"
      "-Dffmpeg=${mesonBool ffmpegSupport}"
      "-Dbluez5=${mesonBool bluezSupport}"
      "-Dbluez5-backend-hsp-native=${mesonBool nativeHspSupport}"
      "-Dbluez5-backend-hfp-native=${mesonBool nativeHfpSupport}"
      "-Dbluez5-backend-ofono=${mesonBool ofonoSupport}"
      "-Dbluez5-backend-hsphfpd=${mesonBool hsphfpdSupport}"
      "-Dpipewire_config_dir=/etc/pipewire"
    ];

    FONTCONFIG_FILE = fontsConf; # Fontconfig error: Cannot load default config file

    doCheck = true;

    postInstall = ''
      mkdir -p $out/nix-support/etc/pipewire/media-session.
      for f in etc/pipewire/*.conf; do $out/bin/spa-json-dump "$f" > "$out/nix-support/$f.json"; done

      moveToOutput "share/systemd/user/pipewire-pulse.*" "$pulse"
      moveToOutput "lib/systemd/user/pipewire-pulse.*" "$pulse"
      moveToOutput "bin/pipewire-pulse" "$pulse"

      mkdir -p $mediaSession/nix-support/etc/pipewire/media-session.d
      for f in etc/pipewire/media-session.d/*.conf; do $out/bin/spa-json-dump "$f" > "$mediaSession/nix-support/$f.json"; done
      moveToOutput "bin/pipewire-media-session" "$mediaSession"
      moveToOutput "etc/pipewire/media-session.d/*.conf" "$mediaSession"
    '';

    passthru.tests = {
      installedTests = nixosTests.installed-tests.pipewire;

      # This ensures that all the paths used by the NixOS module are found.
      test-paths = callPackage ./test-paths.nix {
        paths-out = [
          "share/alsa/alsa.conf.d/50-pipewire.conf"
          "nix-support/etc/pipewire/client.conf.json"
          "nix-support/etc/pipewire/client-rt.conf.json"
          "nix-support/etc/pipewire/jack.conf.json"
          "nix-support/etc/pipewire/pipewire.conf.json"
          "nix-support/etc/pipewire/pipewire-pulse.conf.json"
        ];
        paths-out-media-session = [
          "nix-support/etc/pipewire/media-session.d/alsa-monitor.conf.json"
          "nix-support/etc/pipewire/media-session.d/bluez-monitor.conf.json"
          "nix-support/etc/pipewire/media-session.d/media-session.conf.json"
          "nix-support/etc/pipewire/media-session.d/v4l2-monitor.conf.json"
        ];
        paths-lib = [
          "lib/alsa-lib/libasound_module_pcm_pipewire.so"
          "share/alsa-card-profile/mixer"
        ];
      };
    };

    meta = with lib; {
      description = "Server and user space API to deal with multimedia pipelines";
      homepage = "https://pipewire.org/";
      license = licenses.mit;
      platforms = platforms.linux;
      maintainers = with maintainers; [ jtojnar ];
    };
  };

in self
