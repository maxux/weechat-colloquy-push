# weechat-colloquy-push
weechat perl plugin to send notification to colloquy

# source
Based on perl exemple from: http://colloquy.mobi/bouncers.html

PoC from: https://github.com/benjie/weechat-colloquy

Why rewrite it in perl ? Because I didn't compiled python plugin support on my weechat.

# note
This is a hack for myself at first, maybe this can works for someone else.

The code is not clean, next step is to improve json support and clean a little bit code.

# bugs
The current implementation keep a volatile list of device-token, nothing is saved.

If you reload weechat or the plugin, you need to relaunch your colloquys to (re) register token.
