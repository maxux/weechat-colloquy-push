use strict;
use warnings;
use Socket;
use IO::Socket::SSL;

my $pushServer = "colloquy.mobi";
my $pushServerPort = 7906;

my $SCRIPT_NAME = "colloquy-push";
my $SCRIPT_VERSION = "1.0";

weechat::register(
	$SCRIPT_NAME,
	"Maxime Daniel <root\@maxux.net>",
	$SCRIPT_VERSION,
	"GPL3",
	"Send iOS push notification to colloquy PUSH API",
	"",
	""
);

weechat::hook_print("", "irc_privmsg", "", 1, "highlight_handler", "");
weechat::hook_signal("*,irc_outtags_push", "push_handler", "");

my $socket;
my %clients = ();
my $current = "";

my %escapedMap = ( 
	"\\" => '\\', 
	"\r" => 'r', 
	"\n" => 'n', 
	"\t" => 't', 
	"\a" => 'a',
	"\b" => 'b',
	"\e" => 'e',
	"\f" => 'f',
	"\"" => '"',
	"\$" => '$',
	"\@" => '@'
);

sub chr2hex {
	my $c = shift;
	return sprintf("%04x", ord($c));
}

sub escape {
	local $_ = shift;
	s/([\a\b\e\f\r\n\t\"\\\$\@])/\\$escapedMap{$1}/sg;
	s/([\x00-\x1f\x{7f}-\x{ffff}])/"\\u" . chr2hex($1)/gse;
	return $_;
}

sub pushChatMessage {
	my $deviceToken = shift;
	my $message = shift;
	my $action = shift;
	my $sender = shift;
	my $room = shift;
	my $server = shift;
	my $sound = shift;
	my $badge = shift;

	my $payload = "{";
	my $first = 1;

	if($deviceToken) {
		$payload .= '"device-token":"' . escape($deviceToken) . '"';
		$first = 0;
	}

	if($message) {
		$payload .= ',' unless $first;
		$payload .= '"message":"' . escape($message) . '"';
		$first = 0;
	}

	if($action) {
		$payload .= ',' unless $first;
		$payload .= '"action":true';
		$first = 0;
	}

	if($sender) {
		$payload .= ',' unless $first;
		$payload .= '"sender":"' . escape($sender) . '"';
		$first = 0;
	}

	if($room) {
		$payload .= ',' unless $first;
		$payload .= '"room":"' . escape($room) . '"';
		$first = 0;
	}

	if($server) {
		$payload .= ',' unless $first;
		$payload .= '"server":"' . escape($server) . '"';
		$first = 0;
	}

	if($sound) {
		$payload .= ',' unless $first;
		$payload .= '"sound":"' . escape($sound) . '"';
		$first = 0;
	}

	if($badge) {
		$payload .= ',' unless $first;
		if($badge =~ /^\d+$/) {
			$payload .= '"badge":' . $badge;
		} else {
			$payload .= '"badge":"' . escape($badge) . '"';
		}
		$first = 0;
	}

	$payload .= "}";

	writePushNotification($payload);
}

sub pushAlert {
	my $deviceToken = shift;
	my $alert = shift;
	my $sound = shift;
	my $badge = shift;

	my $payload = "{";
	my $first = 1;

	if($deviceToken) {
		$payload .= '"device-token":"' . escape($deviceToken) . '"';
		$first = 0;
	}

	if($alert) {
		$payload .= ',' unless $first;
		$payload .= '"alert":"' . escape($alert) . '"';
		$first = 0;
	}

	if($sound) {
		$payload .= ',' unless $first;
		$payload .= '"sound":"' . escape($sound) . '"';
		$first = 0;
	}

	if($badge) {
		$payload .= ',' unless $first;
		if($badge =~ /^\d+$/) {
			$payload .= '"badge":' . $badge;
		} else {
			$payload .= '"badge":"' . escape($badge) . '"';
		}
		$first = 0;
	}

	$payload .= "}";

	writePushNotification($payload);
}

sub connectToPushServer {
	{
		local $^W = 0;
		return 1 if $socket and $socket->connected();
	}

	$socket = IO::Socket::SSL->new(Domain => &AF_INET, PeerAddr => $pushServer, PeerPort => $pushServerPort, SSL_verify_mode => 0);
	return ($socket and $socket->connected());
}

sub writePushNotification {
	my $payload = shift or return;

	my $attempts = 0;
	$attempts++ while !connectToPushServer() and $attempts < 10;

	{
		local $^W = 0;
		return unless $socket and $socket->connected();
	}

	print $socket $payload;
}

sub disconnectFromPushServer {
	return unless $socket;
	$socket->close();
	$socket = undef;
}

sub highlight_handler {
	my ($data, $buffer, $date, $tags, $displayed, $highlight, $prefix, $message) = @_;
	
	if($highlight == 0) {
		return 0;
	}
	
	my $bufname = weechat::buffer_get_string($buffer, "short_name");
	
	foreach my $item (keys %clients) {
		pushChatMessage($item, $message, 0, $prefix, $bufname, "", $clients{$item}{"hl-sound"});
	}
}

sub push_handler {
	my ($tag, $source, $content) = @_;
	my @args = split(/ /, $content);
	
	# get action and trim it
	my $action = $args[1];
	
	# pre-check end-device
	if($action =~ /end-device/) {
		$current = "";
		
		foreach my $item (keys %clients) {
			weechat::print("", "colloquy: device registered: $item");
		}

		return 0;
	}
	
	# checking content
	my $value = $args[2];
	$value =~ s/^://;
	
	# weechat::print("", "[PUSH] $action -> $value");
	
	if($action =~ /add-device/) {
		weechat::print("", "colloquy: new device token: $value");
		
		$clients{$value}{"hash"} = $value;
		$current = $value;
	}
	
	if($action =~ /service/) {
		# FIXME
		$clients{$current}{"service"} = $value;
	}
	
	if($action =~ /connection/) {
		# FIXME
		$clients{$current}{"connection"} = $value;
	}
	
	if($action =~ /highlight-sound/) {
		$clients{$current}{"hl-sound"} = $value;
	}
	
	if($action =~ /message-sound/) {
		$clients{$current}{"msg-sound"} = $value;
	}
	
	return 0;
}
