
package CaUMa;

	use REST::Client;
	use JSON;
	use Mail::SpamAssassin::Logger;
	use Mail::SpamAssassin::Plugin;
	our @ISA = qw(Mail::SpamAssassin::Plugin);
	
	no warnings 'experimental::smartmatch';

	sub new {
		my ($class, $mailsa) = @_;

		$class = ref($class) || $class;
		my $self = $class->SUPER::new($mailsa);
		bless ($self, $class);

		Mail::SpamAssassin::Plugin::info("Iniciando plugin CaUMa");
		
		$self->register_eval_rule("check_cauma");
		return $self;
	}

	sub check_cauma {
		my ($self, $msg) = @_;

		my $array = $msg->get_decoded_body_text_array();
		my $body = join (' ', @$array);
		my @links = ();
		
		while($body =~ /((http|ftp)s?:)?\/\/([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:\/~+#-]*[\w@?^=%&\/~+#-])?/gi){
			if (!($& ~~ @links)){
				push(@links, $&);
			}
		}
		
		if (@links == 0){
			return 0;
		}

		my $data = {
			"client" => {
				"clientLogin" => $msg->{conf}->{descriptions}->{CAUMA_LOGIN},
				"clientKey" => $msg->{conf}->{descriptions}->{CAUMA_KEY},
			},
			"threatEntries" => \@links
		};
		
		my $client = REST::Client->new();
		$client->setTimeout(10);
		$client->POST(
			'https://cauma.pop-ba.rnp.br/api/v2.0/find',
			to_json($data),
			{'Accept' => 'application/json', 'Content-Type' => 'application/json'}
		);
		if( $client->responseCode() != '200' ){
			Mail::SpamAssassin::Plugin::info("Problema de comunicações com CaUMa");
			return 0;
		}
		
		my $response = from_json($client->responseContent());
		my $results = $response->{'data'}->{'threatResults'};
		foreach $item (@$results){
			if ($item){
				return 1;
			}
		}
		return 0;
	}

1;