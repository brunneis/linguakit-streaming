#!/usr/bin/env perl

#ProLNat NER 
#autor: Grupo ProLNat@GE, CITIUS
#Universidade de Santiago de Compostela

package Ner;

#<ignore-block>
use strict; 
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
use utf8;
#<ignore-block>

sub init() {
	# Absolute path 
	use File::Basename;#<ignore-line>
	my $abs_path = ".";#<string>
	$abs_path = dirname(__FILE__);#<ignore-line>
	unshift(@INC, $abs_path);#<ignore-line>
	do "store_lex.perl";

	##ficheiros de recursos
	$Ner::Entry;#<ref><hash><string>
	$Ner::Lex;#<ref><hash><integer>
	$Ner::StopWords;#<ref><hash><string>
	$Ner::Noamb;#<ref><hash><boolean>
	($Ner::Entry,$Ner::Lex,$Ner::StopWords,$Ner::Noamb) = Store::read();

	##lexico de formas ambiguas
	my $AMB;#<file>
	open ($AMB, $abs_path."/lexicon/ambig.txt") or die "O ficheiro de palavras ambiguas não pode ser aberto: $!\n";
	binmode $AMB,  ':utf8';#<ignore-line>


	##variaveis globais
	##para sentences e tokens:
	$Ner::UpperCase = "[A-ZÁÉÍÓÚÀÈÌÒÙÂÊÎÔÛÑÇÜÃẼÕĨŨ]";#<string>
	$Ner::LowerCase = "[a-záéíóúàèìòùâêîôûñçüãẽĩõũ]";#<string>
	$Ner::Punct =  qr/[\,\;\«\»\“\”\'\"\&\$\#\=\(\)\<\>\!\¡\?\¿\\\[\]\{\}\|\^\*\€\·\¬\…\-\+]/;#<string>
	$Ner::Punct_urls = qr/[\:\/\~]/;#<string>

	##########CARGANDO RECURSOS COMUNS
	##cargando o lexico freeling e mais variaveis globais
	%Ner::Ambig=();#<hash><boolean>
	##carregando palavras ambiguas
	while (my $t = <$AMB>) {#<string>
		$t = Trim ($t);
		$Ner::Ambig{$t}=1;
	}
	close $AMB;


	######################info dependente da língua!!!####################################################################################
	$Ner::Prep = "(de|del|von)";#<string>   ##preposiçoes que fazem parte dum NP composto
	$Ner::Art = "(el|la|los|las)";#<string>  ##artigos que fazem parte dum NP composto
	$Ner::currency = "(euro|euros|dólar|dólares|peseta|pesetas|yen|yenes|escudo|escudos|franco|francos|real|reales|€)";#<string> 
	$Ner::measure = "(kg|kilogramo|quilogramo|gramo|g|centímetro|cm|hora|segundo|minuto|tonelada|tn|metro|m|km|kilómetro|quilómetro|%)";#<string> 
	$Ner::quant = "(ciento|cientos|miles|millón|millones|billón|billones|trillón|trillones)";#<string> 
	$Ner::cifra = "(dos|tres|catro|cinco|seis|siete|ocho|nueve|diez|cien|mil)";#<string>   ##hai que criar as cifras básicas: once, doce... veintidós, treinta y uno...
	$Ner::meses =  "(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)";#<string> 
	######################info dependente da língua!!!####################################################################################
}

sub ner {
    
	my $N=10;#<integer>
	my @saida=();#<list><string> 
	my $SEP = "_";#<string>
	my %Tag=();#<hash><string>
	my $Candidate;#<string>
	my $Nocandidate;#<string>
	#my $ContarCandidatos=0;
	#my $linhaFinal;
	my $token;#<string>
	my $adiantar;#<integer>
    
	my ($lines) = @_;#<ref><list><string>
	my @tokens=@{$lines};#<list><string>


	for (my $i=0; $i<=$#tokens; $i++) {#<integer>

		##marcar fim de frase
		$Tag{$tokens[$i]} = "";
		my $lowercase = lowercase ($tokens[$i]);#<string>
		if ($tokens[$i] =~ /^[ ]*$/) {
			$tokens[$i] = "#SENT#";
		}
		my $k = $i - 1;#<string>
		my $j = $i + 1;#<string>

		#if  ($Ner::Lex->{$lowercase}) {print STDERR "---> #$lowercase#\n"};
		####CADEA COM TODAS PALAVRAS EM MAIUSCULA
		if ($tokens[$i] =~ /^$Ner::UpperCase+$/ && $tokens[$j] =~ /^$Ner::UpperCase+$/ && $Ner::Lex->{$lowercase} && $Ner::Lex->{lowercase($tokens[$j])} ) {
			$Tag{$tokens[$i]} = "UNK"; ##identificamos cadeas de tokens so em maiusculas e estao no dicionario 
		}elsif   ($tokens[$i] =~ /^$Ner::UpperCase+$/ && $tokens[$k] =~ /^$Ner::UpperCase+$/ && $Ner::Lex->{$lowercase} && $Ner::Lex->{lowercase($tokens[$k])} &&
			($tokens[$j] =~ /^(\#SENT\#|\<blank\>|\"|\»|\”|\.|\-|\s|\?|\!)$/ || $i == $#tokens ) ) { ##ultimo token de uma cadea com so maiusculas
			$Tag{$tokens[$i]} = "UNK";        
		}
		####CADEAS ENTRE ASPAS com palavras que começam por maiuscula 
		elsif ($tokens[$k]  =~ /^(\"|\“|\«|\')/ && $tokens[$i] =~ /^$Ner::UpperCase/ && $tokens[$i+1] =~ /^$Ner::UpperCase/ && $tokens[$i+2] =~ /[\"\»\”\']/) {
			#print STDERR  "#$tokens[$i]# --- #$tokens[$k]#\n";
			$Candidate =  $tokens[$i] . $SEP . $tokens[$i+1] ;  
			$i = $i + 1; 
			$tokens[$i] = $Candidate;                
		} elsif   ($tokens[$k]  =~ /^(\"|\“|\«|\')/ && $tokens[$i] =~ /^$Ner::UpperCase/ && $tokens[$i+1] =~ /^$Ner::UpperCase/ && $tokens[$i+2] =~ /^$Ner::UpperCase/ && $tokens[$i+3] =~ /[\"\»\”\']/) {
			#print STDERR  "#$tokens[$i]# --- #$tokens[$k]#\n";
			$Candidate =  $tokens[$i] . $SEP . $tokens[$i+1] . $SEP . $tokens[$i+2] ;   
			$i = $i + 2;
			$tokens[$i] = $Candidate;            
		} elsif   ($tokens[$k]  =~ /^(\"|\“|\«|\')/ && $tokens[$i] =~ /^$Ner::UpperCase/ && $tokens[$i+1] =~ /^$Ner::UpperCase/ && $tokens[$i+2] =~ /^$Ner::UpperCase/ && $tokens[$i+3] =~ /^$Ner::UpperCase/ && $tokens[$i+4] =~ /[\"\»\”\']/) {
			$Candidate =  $tokens[$i] . $SEP . $tokens[$i+1] . $SEP .  $tokens[$i+2] . $SEP . $tokens[$i+3];   
			$i = $i + 3;   
			$tokens[$i] = $Candidate;           
		} elsif   ($tokens[$k]  =~ /^(\"|\“|\«|\')/ && $tokens[$i] =~ /^$Ner::UpperCase/ && $tokens[$i+1] =~ /^$Ner::UpperCase/ && $tokens[$i+2] =~ /^$Ner::UpperCase/ && $tokens[$i+3] =~ /^$Ner::UpperCase/ && $tokens[$i+4] =~ /^$Ner::UpperCase/ && $tokens[$i+5] =~ /[\"\»\”\']/) {
			$Candidate =  $tokens[$i] . $SEP . $tokens[$i+1] . $SEP .  $tokens[$i+2] . $SEP . $tokens[$i+3] . $SEP . $tokens[$i+4];   
			$i = $i + 4;   
			$tokens[$i] = $Candidate;           
		} elsif   ($tokens[$k]  =~ /^(\"|\“|\«|\')/ && $tokens[$i] =~ /^$Ner::UpperCase/ && $tokens[$i+1] =~ /^$Ner::UpperCase/ && $tokens[$i+2] =~ /^$Ner::UpperCase/ && $tokens[$i+3] =~ /^$Ner::UpperCase/ && $tokens[$i+4] =~ /^$Ner::UpperCase/  && $tokens[$i+5] && $tokens[$i+6] =~ /[\"\»\”\']/) {
			$Candidate =  $tokens[$i] . $SEP . $tokens[$i+1] . $SEP .  $tokens[$i+2] . $SEP . $tokens[$i+3] . $SEP . $tokens[$i+4] . $SEP . $tokens[$i+5];   
			$i = $i + 5;   
			$tokens[$i] = $Candidate;           
		}
		###Palavras que começam por maiúscula e nao estao no dicionario com maiusculas
		elsif ( $tokens[$i] =~ /^$Ner::UpperCase/ && $Ner::Noamb->{$tokens[$i]} ) { ##começa por maiúscula e e um nome proprio nao ambiguo no dicionario
		    $Tag{$tokens[$i]} = "NP00000";
		}elsif ( $tokens[$i] =~ /^$Ner::UpperCase/ && $Ner::Ambig{$lowercase} ) { ##começa por maiúscula e e um nome proprio ambiguo no dicionario
			$Tag{$tokens[$i]} = "NP00000";
		}
	        #elsif   ( ($tokens[$i] =~ /^$Ner::UpperCase/) &&  !$Ner::Lex{$lowercase} && 
		elsif    ($tokens[$i] =~ /^$Ner::UpperCase/ &&  !$Ner::StopWords->{$lowercase} &&
			$tokens[$k] !~ /^(\#SENT\#|\<blank\>|\"|\“|\«|\.|\-|\s|\¿|\u00A1|\?|\!|\:|\`\`)$/ && $tokens[$k] !~ /^\.\.\.$/  && $i>0 ) { ##começa por maiúscula e nao vai a principio de frase
			$Tag{$tokens[$i]} = "NP00000";
			#print  STDERR "1TOKEN::: ##$i## --  ##$tokens[$i]## - - #$Tag{$tokens[$i]}# --  prev:#$tokens[$k]# --  post:#$tokens[$j]#\n" if ($tokens[$i] eq "De");
		}
		##elsif   ( ($tokens[$i] =~ /^$Ner::UpperCase/ &&  !$Ner::Lex{$lowercase} &&
		elsif (($tokens[$i] =~ /^$Ner::UpperCase/ &&  !$Ner::StopWords->{$lowercase} &&
		  $tokens[$k]  =~ /^(\#SENT\#|\<blank\>|\"|\“|\«|\.|\-|\s|\¿|\u00A1|\?|\!|\:|\`\`)$/) || ($i==0) ) { ##começa por maiúscula e vai a principio de frase 
			#$token = lowercase ($tokens[$i]);
			#print STDERR "2TOKEN::: lowercase: #$lowercase# -- token: #$tokens[$i]# --  token_prev: #$tokens[$k]# --  post:#$tokens[$j]#--- #$Tag{$tokens[$i]}#\n" if ($tokens[$i] eq "De");       
			if (!$Ner::Lex->{$lowercase} || $Ner::Ambig{$lowercase}) {
				#print STDERR "--AMBIG::: #$lowercase#\n";
				$Tag{$tokens[$i]} = "NP00000"; 
			   #print STDERR "OKKKK::: lowercase: #$lowercase# -- token: #$tokens[$i]# --  token_prev: #$tokens[$k]#  --  post:#$tokens[$j]#\n" ;       
			}
			#print STDERR "##$tokens[$i]## -  #$tokens[$k]#\n" if ($tokens[$i] eq "De");
		}
  
		##if   ( $tokens[$i] =~ /^$Ner::UpperCase$Ner::LowerCase+/ && ($Ner::StopWords{$lowercase} && ($tokens[$k]  =~ /^(\#SENT\#|\<blank\>|\"|\“|\«|\.|\-|\s|\¿|\u00A1)$/) || ($i==0)) ) {   }##se em principio de frase a palavra maiuscula e uma stopword, nao fazemos nada
		if (($tokens[$i] =~ /^$Ner::UpperCase$Ner::LowerCase+/ && $Ner::Lex->{$lowercase} &&  !$Ner::Ambig{$lowercase}) && ($tokens[$k]  =~ /^(\#SENT\#|\<blank\>|\"|\“|\«|\.|\-|\s|\¿|\u00A1|\?|\!|\:|\`\`)$/  || $i==0) ) {  
			#print  STDERR "1TOKEN::: ##$lowercase## // #!$Ner::Ambig{$lowercase}# - - #$Tag{$tokens[$i]}# --  #$tokens[$k]#\n" ;      
		}##se em principio de frase a palavra maiuscula e está no lexico sem ser ambigua, nao fazemos nada
		##caso que seja maiuscula
		###construimos candidatos para os NOMES PROPRIOS COMPOSTOS#############################################################
		elsif  ($tokens[$i] =~ /^$Ner::UpperCase$Ner::LowerCase+/) {
			#print "##$tokens[$i]## - #$Tag{$tokens[$i]}# --  #$tokens[$k]# ---- #$Ner::StopWords{$lowercase}#\n"; 
			$Candidate = $tokens[$i]  ;
			#$Candidate = $tokens[$i];
			#$Nocandidate = $tokens[$i] ;
			#print  STDERR "4TOKEN::: ##$tokens[$i]## - - #$Tag{$tokens[$i]}# --  #$tokens[$k]#\n" ;         
			my $count = 1;#<integer>
			my $found = 0;#<boolean>
			#print  STDERR "Begin: ##$i## - ##$count##- $tokens[$i]\n";
			#while ( (!$found) && ($count < $N) )    {
			while  (!$found) {
				my $j = $i + $count;#<integer>

				#chomp $tokens[$j];
				#print  STDERR "****Begin: ##$i## - ##$j##- #$tokens[$i]# --- #$tokens[$j]#\n";
				if ($tokens[$j] eq "" || ($tokens[$j] =~ /^($Ner::Art)$/i && $tokens[$j-1] !~ /^($Ner::Prep)$/i) ) { #se chegamos ao final de uma frase sem ponto ou se temos um artigo sem uma preposiçao precedente, paramos (Pablo el muchacho)
					$found=1;
				}elsif ( ($tokens[$j] !~ /^$Ner::UpperCase$Ner::LowerCase+/ ||  $Candidate =~ /($Ner::Punct)|($Ner::Punct_urls)/ ) &&
				  #($tokens[$j] !~ /^($Ner::Prep)$/ && $tokens[$j+1] !~ /^($Ner::Art)$/ && $tokens[$j+1] !~ /^$Ner::UpperCase$Ner::LowerCase+/ )  )  { 
				  ($tokens[$j] !~ /^($Ner::Prep)$/i && $tokens[$j] !~ /^($Ner::Art)$/i )  )  { 
					#print  STDERR "4TOKEN::: ##$i## - ##$j## - ##$count##----> ##$tokens[$i]## - - #$tokens[$j]# --  #$tokens[$k]#\n" ;
					$found = 1;
				}else {
					$Candidate .= $SEP . $tokens[$j] ;
					#$Nocandidate .=  " " . $tokens[$j] ; 
					$count++;
					#print STDERR "okk: #$Candidate#\n";
				}
			}
			#print STDERR "---------#$count# -- #$Candidate# - #$SEP#  - #$N#\n";
			if ( ($count > 1) && ($count <= $N) && ($Candidate !~ /$Ner::Punct$SEP/ || $Candidate !~ /$Ner::Punct_urls$SEP/) &&  $Candidate !~ /$SEP($Ner::Prep)$/ && $Candidate !~ /$SEP($Ner::Prep)$SEP($Ner::Art)$/  ) {
				#print STDERR "----------#$Candidate#\n";
				$i = $i + $count - 1;
				$tokens[$i] =  $Candidate ; 
			}elsif ( ($count > 1) && ($count <= $N) && ($Candidate !~ /$Ner::Punct$SEP/ || $Candidate !~ /$Ner::Punct_urls$SEP/) &&  $Candidate =~ /$SEP($Ner::Prep)$/i ) {
				$i = $i + $count - 2;
				$Candidate =~ s/$SEP($Ner::Prep)$//;  
				$tokens[$i] =  $Candidate ;
				#print STDERR "OK----------#$Candidate#\n";
			}elsif ( ($count > 1) && ($count <= $N) && ($Candidate !~ /$Ner::Punct$SEP/ || $Candidate !~ /$Ner::Punct_urls$SEP/) &&  $Candidate =~ /$SEP($Ner::Prep)$SEP($Ner::Art)$/i ) {
				$i = $i + $count - 3;
				$Candidate =~ s/$SEP($Ner::Prep)$SEP($Ner::Art)$//i;  
				$tokens[$i] =  $Candidate ;
				#print STDERR "----------#$Candidate#\n"; 
			}elsif ( ($count > 1) && ($count <= $N) && ($Candidate !~ /$Ner::Punct$SEP/ || $Candidate !~ /$Ner::Punct_urls$SEP/) &&  $Candidate =~ /SEP($Ner::Art)$/i ) {
				$i = $i + $count - 2;
				$Candidate =~ s/$SEP($Ner::Art)$//i;  
				$tokens[$i] =  $Candidate ;
				#print STDERR "----------#$Candidate#\n"; 
			}
		}
		###FIM CONSTRUÇAO DOS NP COMPOSTOS##############################

		##NP se é composto
		if ($tokens[$i] =~ /[^\s]_[^\s]/ ) { 
			$Tag{$tokens[$i]} = "NP00000" ;     
		}##se não lhe foi assigado o tag NP, entao UNK (provisional)
		elsif   (! $Tag{$tokens[$i]}) {
			$Tag{$tokens[$i]} = "UNK" ; 
		}
		##Numeros romanos 
                elsif ($tokens[$i] =~ /^$Ner::UpperCase/ && $Ner::Entry->{$tokens[$i]} =~ / Z$/) {
                    $Tag{$tokens[$i]} = $Ner::Entry->{$tokens[$i]};
                    #print STDERR "OKK $tokens[$i] - #$Tag{$tokens[$i]}#\n";
                }

		##se é UNK (é dizer nao é NP), entao vamos buscar no lexico
		if ($Tag{$tokens[$i]} eq "UNK") {
			$token = lowercase ($tokens[$i]);
			#print STDERR "2--: $tokens[$i] - $Tag{$tokens[$i]}\n";
			if ($Ner::Lex->{$token}) {
				$Tag{$tokens[$i]} = $Ner::Entry->{$token};
				#print STDERR "3--: $tokens[$i] - $Tag{$tokens[$i]}\n";
			}elsif ($tokens[$i] =~ /\-/) { ##se o token é composto, dever ser um sustantivo
				$Tag{$tokens[$i]} = "$tokens[$i] NC00000";
			}
		}elsif ($Tag{$tokens[$i]} eq "NP00000") {
			$token = lowercase ($tokens[$i]); 
		}
		$adiantar=0;
		##os numeros, medidas e datas #USAR O FICHEIRO QUANTITIES.DAT##################

		##CIFRAS OU NUMEROS
		if ($tokens[$i] =~ /^[0-9]+$/ || $tokens[$i] =~ /^$Ner::cifra$/) {
			$token = $tokens[$i];
			$Tag{$tokens[$i]} = "Z"; 
		}         
		##MEAUSURES
		if  ($Tag{$tokens[$i]} =~ /^Z/ && $tokens[$i+1] =~ /^$Ner::measure(s|\.)?$/i) {
			$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1] ;
			$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: kg=kilogramo,...
			$Tag{$tokens[$i]} = "Zu"; 
			$adiantar=1 ;
		}elsif ($Tag{$tokens[$i]} =~ /^Z/  && $tokens[$i+1] =~ /^$Ner::quant$/i &&  $tokens[$i+2] =~ /^$Ner::measure(s|\.)?$/i) {
			$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1] . "_" . $tokens[$i+2]  ;
			$token = lc ($tokens[$i]); 
			$Tag{$tokens[$i]} = "Zu"; 
			$adiantar=2;	        
		}
		##CURRENCY
		elsif ($Tag{$tokens[$i]} =~ /^Z/ && $tokens[$i+1] =~ /^$Ner::currency$/i) {
			$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1];
			$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: euros=euro...
			$Tag{$tokens[$i]} = "Zm"; 
			$adiantar=1;	        
		} elsif ($Tag{$tokens[$i]} =~ /^Z/ && $tokens[$i+1] =~ /^\$$/i) {
		$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1];
		$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: euros=euro...
		$Tag{$tokens[$i]} = "Zm"; 
		$adiantar=1;        
		} elsif ($Tag{$tokens[$i]} =~ /^Z/  && $tokens[$i+1] =~ /^$Ner::quant$/i && $tokens[$i+2] =~ /^de$/i && $tokens[$i+3] =~ /^$Ner::currency$/i) {
		$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1] . "_" . $tokens[$i+2] . "_" . $tokens[$i+3] ;
		$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: euros=euro...
		$Tag{$tokens[$i]} = "Zm"; 
		$adiantar=3;	           
		} elsif ($Tag{$tokens[$i]} =~ /^Z/  && $tokens[$i+1] =~ /^$Ner::quant$/i && $tokens[$i+2] =~ /^$Ner::currency$/i) {
			$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1] . "_" . $tokens[$i+2]  ;
			$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: euros=euro...
			$Tag{$tokens[$i]} = "Zm"; 
			$adiantar=2;	      
		} elsif ($Tag{$tokens[$i]} =~ /^Z/  && $tokens[$i+1] =~ /^de$/i && $tokens[$i+2] =~ /^$Ner::currency$/i) {
		$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1] . "_" . $tokens[$i+2] ;
		$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: euros=euro...
		$Tag{$tokens[$i]} = "Zm"; 
		$adiantar=2;	          
		}
		##QUANTITIES
		elsif ($Tag{$tokens[$i]} =~ /^Z/ && $tokens[$i+1] =~ /^$Ner::quant$/i) {
			$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1] ;
			$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: kg=kilogramo,...
			$Tag{$tokens[$i]} = "Z"; 
			$adiantar=1 ;
		}
		
		##DATES
		elsif ($Tag{$tokens[$i]} =~ /^Z/  && $tokens[$i+1] =~ /^de$/i && $tokens[$i+2] =~ /^$Ner::meses$/i  && $tokens[$i+3] =~ /^de$/i && $tokens[$i+4] =~ /[0-9]+/) {
			$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1] . "_" . $tokens[$i+2] . "_" . $tokens[$i+3] . "_" . $tokens[$i+4]  ;
			$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: kg=kilogramo,...
			$Tag{$tokens[$i]} = "W"; 
			$adiantar=4;	        
		}elsif ($tokens[$i] =~ /^$Ner::meses$/i  && $tokens[$i+1] =~ /^de$/i && $tokens[$i+2] =~ /^[0-9]+$/) {
			$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1]  . "_" . $tokens[$i+2] ;
			$token = lc ($tokens[$i]);
			$Tag{$tokens[$i]} = "W"; 
			$adiantar=2;   
		}elsif ($Tag{$tokens[$i]} =~ /^Z/  && $tokens[$i+1] =~ /^de$/i && $tokens[$i+2] =~ /^$Ner::meses$/i) {
			$tokens[$i] = $tokens[$i] . "_" . $tokens[$i+1]  . "_" . $tokens[$i+2] ;
			$token = lc ($tokens[$i]); ##haveria que lematizar/normalizar o token: kg=kilogramo,...
			$Tag{$tokens[$i]} = "W"; 
			$adiantar=2;   
		}
		#################################FIM DATAS E NUMEROS
		
		#agora etiquetamos os simbolos de puntuaçao
		if ($tokens[$i] eq "\.") {
			$token = "\.";
			$Tag{$tokens[$i]} = "Fp"; 
		} elsif ($tokens[$i] eq "#SENT#" && $tokens[$i-1] ne "\." && $tokens[$i-1] ne "<blank>" ){
			# print STDERR "--- #$tokens[$i]# #$tokens[$i-1]#\n";
			$tokens[$i] = "<blank>";
			$token = "<blank>";
			$Tag{$tokens[$i]} = "Fp"; 
		}elsif ($tokens[$i] =~ /^$Ner::Punct$/ || $tokens[$i] =~ /^$Ner::Punct_urls$/ || 
			$tokens[$i] =~ /^(\.\.\.|\`\`|\'\'|\<\<|\>\>|\-\-)$/ ) {
			$Tag{$tokens[$i]} = punct ($tokens[$i]);
			$token = $tokens[$i]; 
			#print STDERR "token: #$token# -- #$tokens[$i]# -- #$Tag{$tokens[$i]}# \n";
		}
		##as linhas em branco eliminam-se 
		if ($tokens[$i] eq  "#SENT#") {
			next;
		}
	 
		##parte final..
		my $tag = $Tag{$tokens[$i]};#<string>
		$tag = $token . " " . $tag if ( $tag =~ /^(UNK|F|NP|Z|W)/  );

		push (@saida, "$tokens[$i] $tag");

		if($Tag{$tokens[$i]} eq "Fp"){
		
			push (@saida, "");

		}

		$Tag{$tokens[$i]} = "";
		$i += $adiantar if ($adiantar); ##adiantar o contador se foram encontradas expressoes compostas    
	}
	print "\n".join("\n", @saida);
	print "\nEOC";
	return \@saida;
}

#<ignore-block>
init();
for(;;) {
	my $value=<STDIN>;
	my @lines = eval($value);

	for (my $i=0; $i<=$#lines; $i++) {
		chomp $lines[$i];
	}

	ner(\@lines);
}
#<ignore-block>

###OUTRAS FUNÇOES

sub punct {
	my ($p) = @_ ;#<string>
	my $result;#<string>

	if ($p eq "\.") {
		$result = "Fp"; 
	}elsif ($p eq "\,") {
		$result = "Fc"; 
	}elsif ($p eq "\:") {
		$result = "Fd"; 
	}elsif ($p eq "\;") {
		$result = "Fx"; 
	}elsif ($p =~ /^(\-|\-\-)$/) {
		$result = "Fg"; 
	}elsif ($p =~ /^(\'|\"|\`\`|\'\')$/) {
		$result = "Fe"; 
	}elsif ($p eq "\.\.\.") {
		$result = "Fs"; 
	}elsif ($p =~ /^(\<\<|«|\“)/) {
		$result = "Fra"; 
	}elsif ($p =~ /^(\>\>|»|\”)/) {
		$result = "Frc"; 
	}elsif ($p eq "\%") {
		$result = "Ft"; 
	}elsif ($p =~ /^(\/|\\)$/) {
		$result = "Fh"; 
	}elsif ($p eq "\(") {
		$result = "Fpa"; 
	}elsif ($p eq "\)") {
		$result = "Fpt"; 
	}elsif ($p eq "\¿") {
		$result = "Fia"; 
	}elsif ($p eq "\?") {
		$result = "Fit"; 
	}elsif ($p eq "\u00A1") {
		$result = "Faa"; 
	}elsif ($p eq "\!") {
		$result = "Fat"; 
	}elsif ($p eq "\[") {
		$result = "Fca"; 
	}elsif ($p eq "\]") {
		$result = "Fct"; 
	}elsif ($p eq "\{") {
		$result = "Fla"; 
	}elsif ($p eq "\}") {
		$result = "Flt"; 
	}elsif ($p eq "\…") {
		$result = "Fz"; 
	}elsif ($p =~ /^[\+\*\#\&]$/) {
		$result = "Fz"; 
	}
	return $result;
}

sub lowercase {
	my ($x) = @_ ;#<string>
	$x = lc ($x);
	$x =~  tr/ÁÉÍÓÚÇÑ/áéíóúçñ/;

	return $x;    
}

sub Trim {
	my ($x) = @_ ;#<string>

	$x =~ s/^[\s]*//;  
	$x =~ s/[\s]$//;  

	return $x;
}  
