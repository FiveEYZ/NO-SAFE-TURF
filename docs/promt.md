Detta är ett redan påbörjat projekt. Följande prompt uppdaterar
kraven för det fortsatta arbetet.

Börja med att läsa befintlig kod, dokumentation och AGENTS.md.
Kartlägg vad som redan fungerar, vad som är delvis implementerat
och vad som saknas jämfört med kraven.

Fortsätt från befintligt arbete. Skapa inte ett nytt projekt och
skriv inte om fungerande delar utan ett konkret tekniskt skäl.
Bevara befintligt projektnamn och relevanta teknikval där de
är förenliga med de nya kraven.

Anpassa arbetsplanen till återstående arbete. Använd den angivna
modellfördelningen för kommande agentuppgifter.

Skydda befintlig konfiguration, hemligheter och spelardata.
Genomför inte wipe, destruktiva databasmigreringar eller
produktionsändringar utan mitt uttryckliga godkännande.

Redovisa först kort vilka ändringar de nya kraven innebär
och fortsätt därefter med implementationen.

Du är teknisk projektledare och huvudutvecklare för ett nytt spelläge till GTA V Enhanced via FiveM. Bygg projektet med flera samarbetande agenter.

Målet är en kriminalitets- och överlevnadsserver inspirerad av ROB RUN, med gäng, spelarpoliser, rån, territoriekrig, gömställen, räder och veckovisa wipes.

Använd arbetsnamnet NO SAFE TURF tills jag väljer något annat. Använd egen kod, egen visuell identitet och egna eller korrekt licensierade tillgångar.

Arbeta fram till en fungerande, dokumenterad och testbar första version. Stanna inte vid en plan eller kodskisser. Redovisa vad som faktiskt har testats och vad som återstår att verifiera inne i GTA.

OBLIGATORISKA PROJEKTKRAV

- Plattformen är FiveM för GTA V Enhanced på PC.
- Jag kommer att använda en extern MariaDB-databas.
- Hela modden ska vara på engelska.
- Slutleveransen ska innehålla ett fungerande txAdmin-recept för enkel installation genom txAdmin Server Deployer.
- Modden får inte kräva Python för installation, start, drift, schemalagda uppgifter, wipes, backup eller återställning.
- Leverera färdigbyggda gränssnittsfiler så att serverägaren inte behöver bygga frontend för att installera modden.
- Inga betalda resurser ska vara obligatoriska.
- Kommunicera med mig på svenska.

ARBETSSÄTT OCH AGENTER

Använd huvudagenten och minst tre specialiserade agenter inom miljöns tillgängliga samtidighetsgräns:

1. Huvudagent:
   Arkitektur, arbetsfördelning, integration, kodgranskning och slutlig verifiering.

2. Spelsystemagent:
   Gäng, territorier, rån, ekonomi och progression.

3. Polis- och stridsagent:
   Polisroll, larm, efterlysningar, gripanden, död och räder.

4. Infrastruktur- och gränssnittsagent:
   Extern MariaDB, inventarium, wipes, gränssnitt, txAdmin-recept och drift.

Dela upp arbetet i mindre leveranser. Dokumentera vilka filer varje agent ansvarar för och bestäm gemensamma gränssnitt innan parallell implementation.

Undvik samtidiga ändringar i samma filer. Låt agenter granska varandras kritiska kod. Huvudagenten ansvarar för att alla delar fungerar tillsammans.

Om AGENTS.md finns: läs och följ relevanta instruktioner.
Om filen saknas: skapa den i projektets huvudmapp och dokumentera teknikval, kodstruktur, testkommandon och regler för agentsamarbete. Håll den uppdaterad.

FÖRSTA STEGET

Undersök arbetsmappen och befintlig miljö.

Verifiera aktuell officiell dokumentation för:
- FiveM och GTA V Enhanced.
- txAdmin Server Deployer och receptformatet.
- Den valda databasresursens stöd för MariaDB och externa anslutningar.

Använd dessa som utgångspunkt för receptet:
https://github.com/citizenfx/txAdmin-recipes
Följ även receptdokumentationen som repositoryt länkar till.

Anta inte att resurser för GTA V Legacy fungerar i Enhanced. Testa kritiska beroenden tidigt.

Välj en enkel, underhållen teknisk grund. Föredra Lua för spellogik och HTML/CSS/JavaScript eller TypeScript för NUI. Bedöm om ett befintligt ramverk eller fristående resurser passar bäst.

Skriv en kort projektplan, dokumentera antaganden och börja implementera. Fråga bara om information som blockerar arbetet. Fatta rimliga, reversibla beslut själv.

SPRÅK

Allt som spelare och serveradministratörer möter i leveransen ska vara på engelska:
- Menyer och HUD.
- Föremål, roller och uppdrag.
- Notiser och felmeddelanden.
- Hjälptexter och kommandobeskrivningar.
- Administratörsvyer.
- Installationsguide och driftmanual.
- Kommentarer i exempelkonfiguration.

Samla användartexter i språkfiler med engelska som standard, så att fler språk kan läggas till senare. Använd engelska identifierare i koden.

Rapporter och diskussioner med mig ska vara på svenska.

SPELKONCEPT

Bygg ett regelstyrt action- och överlevnadsspel där centrala system fungerar utan ständig administratörsmedverkan.

Första versionen ska sikta på 16–32 samtidiga spelare i ett avgränsat område av Los Santos. Lova inte större spelarantal utan belastningstest.

Kärnloopen:
Begå rån och samla resurser → transportera och säkra bytet → utrusta gänget och förbättra gömstället → ta territorier → försvara tillgångar mot rivaler och polis → tävla om veckans resultat → börja en ny säsong efter wipe.

GÄNG

- Skapa och ansluta till gäng.
- Inbjudningar och roller med tydliga behörigheter.
- Gemensam kassa och förvaring.
- Konfigurerbar medlemsgräns.
- Poäng och topplista per säsong.
- Skydd mot missbruk av medlemsbyten och behörigheter.

SPELARPOLISER

- Val av polisroll med skydd mot exploaterande rollbyten.
- Tjänstgöring, utrustning och tjänstefordon.
- Larm vid brott och tidsbegränsade efterlysningar.
- Gripande, beslag och korta, konfigurerbara påföljder.
- Tydliga regler vid död, frånkoppling och återanslutning.
- Skydd mot att tjänsteutrustning används för obegränsad produktion av pengar eller föremål.
- Fungerande balans vid låg spelar- och polisbemanning.
- NPC-poliser ska inte vara nödvändiga för första versionen.

RÅN OCH EKONOMI

- Minst två kompletta typer av rån.
- Risk, belöning, larm, tidsgräns och cooldown.
- Stöldgods som måste transporteras och säljas eller säkras.
- Pengar, utrustningskostnader och löpande utgifter.
- Rimlig start för nya spelare.
- Skydd mot enkel farming och upprepade belöningsanrop.

INVENTARIUM OCH DÖD

- Servervaliderat inventarium.
- Tydliga regler för vad som tappas och behålls vid död.
- Plundring med avstånds- och behörighetskontroller.
- Respawn och begränsat skydd mot upprepad spawn-kill.
- Hantering av frånkoppling under strid och föremålsöverföringar.
- Skydd mot duplicering och samtidiga uttag.

GÖMSTÄLLEN OCH RÄDER

- Fasta, köpbara eller erövringsbara gömställen.
- Gemensamt lager, kassaskåp och enkla uppgraderingar.
- Räder med förvarning, tidsfönster, mål och cooldown.
- Begränsat offline-skydd.
- Skydd mot upprepade räder mot samma gäng.
- Tydlig gräns för hur mycket en förlorare kan förlora.
- Fritt basbyggande är en framtida utbyggnad.

TERRITORIER

- Ett fåtal konfigurerbara zoner.
- Erövring med synlig status och tydliga regler.
- Krav på aktiv närvaro.
- Motåtgärder mot ensidig farming när få motståndare är online.
- Begränsade ekonomiska fördelar.
- Koppling till säsongspoäng.

EXTERN MARIADB

Jag tillhandahåller en extern MariaDB-server. Installera eller starta inte en lokal databasserver som obligatoriskt beroende.

- Välj en underhållen FiveM-databasresurs med verifierat MariaDB-stöd.
- Gör värdnamn, port, databasnamn, användarnamn och lösenord konfigurerbara.
- Stöd txAdmins databasanslutningsuppgifter via det dokumenterade receptflödet.
- Hårdkoda inga anslutningsuppgifter eller databasnamn.
- Lägg inte lösenord i Git, loggar, klientkod eller NUI.
- Dokumentera TLS-inställningar utifrån vad anslutningsresursen faktiskt stöder.
- Använd parametriserade frågor, lämpliga index och transaktioner.
- Använd utf8mb4 och versionshanterade migreringar.
- Skilj mellan installationsbehörigheter och normala driftbehörigheter.
- Stöd installation i en tom, redan skapad databas om databasleverantören begränsar CREATE DATABASE.
- Kontrollera kompatibiliteten för detta med txAdmin och dokumentera eventuella nödvändiga manuella steg.
- Hantera nätverksavbrott utan att duplicera pengar eller föremål.
- Stoppa ekonomiska förändringar säkert om databasen inte är tillgänglig.
- Återförsök får inte orsaka dubbla transaktioner.
- Begränsa all schemamanipulation och wipe till projektets egna data.

Leverera inga verkliga spelardata, konton, avstängningar eller hemligheter i installationsdatabasen.

VECKOVISA WIPES

- Konfigurerbar veckodag och tid.
- Europe/Stockholm som standardtidszon.
- Korrekt hantering av sommartid.
- Förvarningar och underhållsläge under wipe.
- Beständig säsongsidentifierare och wipe-status.
- Separera kontodata från säsongsdata.
- Återställ ekonomi, inventarier, territorier och uppgraderingar enligt dokumenterade regler.
- Bevara administratörsbehörigheter, avstängningar, inställningar och historiska resultat.
- Samma wipe får aldrig genomföras två gånger.
- Hantera serverkrasch och omstart mitt i wipe.
- Administratörskommando för simulering och test.

Gör verifierad backup till ett villkor för destruktiv wipe. Om backup misslyckas ska wipe avbrytas säkert.

Backup och återställning ska fungera med extern MariaDB utan Python. Använd dokumenterade MariaDB-verktyg eller en verifierbar lösning som databasleverantören erbjuder. Ange tydligt vilka verktyg och behörigheter som behövs.

Om automatisk backup inte kan fungera i den aktuella hostingmiljön ska detta redovisas som en blockerande driftfråga, inte döljas bakom en låtsasbackup.

GRÄNSSNITT

- All text på engelska.
- Enkel HUD med pengar, relevant status och säsongstid.
- Gängmeny, polisvy, inventarium och topplista.
- Tydliga meddelanden om rån, räder, territorier och wipe.
- Sammanhängande eget utseende.
- NUI ska inte stjäla fokus från txAdmins meny.
- Leverera färdigbyggda frontendfiler tillsammans med källkod och bygginstruktioner.

TXADMIN-RECEPT OCH INSTALLATION

Slutleveransen ska innehålla ett riktigt YAML-recept för txAdmin Server Deployer.

Utgå från det aktuella officiella grundreceptet för FiveM Enhanced och följ aktuell receptdokumentation. Hitta inte på YAML-actions eller placeholders.

Receptet ska:
- Hämta modden och nödvändiga redistribuerbara beroenden.
- Använda låsta, verifierade versioner eller commitreferenser.
- Placera resurserna i rätt mappar.
- Installera färdigbyggda NUI-filer.
- Förbereda databasens schema genom dokumenterade mekanismer.
- Ansluta till extern MariaDB med uppgifter från installationsflödet.
- Skapa server.cfg med korrekt startordning.
- Använda dokumenterade txAdmin-placeholders för serverinställningar och databasanslutning.
- Kontrollera databasförutsättningar tidigt.
- Ge begripliga fel vid anslutnings- eller installationsproblem.
- Inte skriva över befintlig spelardata utan uttryckligt beslut.
- Inte kräva Python eller manuell frontendbyggnad.

Integrera moddens administratörsbehörigheter med txAdmins dokumenterade ACE-upplägg. Kontrollera att txAdmins heal/revive, teleport och andra relevanta administrationsfunktioner fungerar utan felaktiga straff eller oavsiktliga ekonomiska följder.

Leverera:
- Receptfil.
- Server.cfg-mall.
- SQL-schema och migreringar.
- Alla nödvändiga releasefiler.
- En stegvis engelsk guide för installation via receptets URL.
- Dokumentation för extern MariaDB.
- Separat instruktion för installation på en befintlig server.
- Uppgraderings- och återställningsinstruktioner.

Ett eget recept ska kunna användas utan att först bli upptaget i txAdmins officiella lista över rekommenderade recept.

Förbered repository och releasepaket så att receptet kan distribueras via en riktig URL. Hitta inte på en GitHub-adress och kalla den fungerande.

Om publiceringsmål eller behörighet saknas: färdigställ alla filer och fråga sedan efter det som krävs för publicering. Markera URL-installationen som overifierad tills den har testats från det verkliga målet.

INGET PYTHONBEROENDE

Ingen del av den levererade lösningens installation eller drift får anropa Python.

Detta omfattar:
- Serverresurser.
- Installationsrecept.
- Databasmigreringar.
- Schemaläggning.
- Wipes.
- Backup och återställning.
- Obligatoriska administrationsverktyg.

Använd Lua, JavaScript/TypeScript, SQL och vid behov dokumenterade PowerShell- eller shellscript samt MariaDBs egna verktyg.

Undvik även Python i projektets bygg- och testverktyg så att projektet är enkelt att underhålla utan Python.

SÄKERHET OCH DRIFT

Klienten får aldrig ensam bestämma pengar, föremål, belöningar, ägarskap eller behörigheter.

Validera serverhändelser, avstånd, tillstånd, cooldowns och roller. Begränsa anropsfrekvens.

Skydda mot återuppspelade anrop, duplicering och samtidiga transaktioner. Logga viktiga ekonomi- och administratörshändelser utan hemligheter.

Lagra hemligheter utanför versionshanteringen. Leverera exempelkonfiguration och tydliga startkontroller.

ETAPPER

1. Startbar Enhanced-kompatibel serverresurs med extern MariaDB.
2. Tidigt fungerande utkast till txAdmin-recept.
3. Komplett spelkedja från rån till säkrat byte.
4. Gäng och spelarpoliser.
5. Gömställen, räder och territorier.
6. Wipe, säsongsresultat och driftverktyg.
7. Engelskt gränssnitt och dokumentation.
8. Ren installation via det slutliga txAdmin-receptet.
9. Integrationstest och balansjustering.

VERIFIERING

Testa särskilt:
- Två spelare försöker ta samma föremål.
- Samma rånbelöning begärs flera gånger.
- Obehöriga anropar polis- eller gängfunktioner.
- Frånkoppling under rån, gripande eller räd.
- Databasavbrott under betalning eller föremålsöverföring.
- Återanslutning till extern MariaDB.
- Omstart mitt i wipe.
- Försök att upprepa genomförd wipe.
- Misslyckad backup före wipe.
- Återställning från riktig backup.
- Ren installation via txAdmin-receptet.
- Start utan Python installerat.
- Minst två GTA-klienter i samma spelsession.

SLUTLEVERANS

Leverera:
- Komplett källkod och färdigbyggda runtime-filer.
- AGENTS.md.
- Databasmigreringar.
- Fungerande txAdmin-recept.
- Exempelkonfiguration utan hemligheter.
- Beroendelista med versioner och licenser.
- Engelsk installations-, spelar- och administratörsguide.
- Dokumentation för backup, wipe och återställning.
- Relevanta automatiska tester.
- Testprotokoll som skiljer genomförda tester från föreslagna tester.
- Kända begränsningar och prioriterad fortsatt utveckling.

Om GTA-klient, servernyckel, extern databas eller publiceringsbehörighet saknas: slutför allt oberoende arbete och ange exakt vad som behövs för återstående steg.

Påstå aldrig att speltest, extern databasanslutning eller txAdmin-installation har fungerat utan faktisk verifiering.

Arbeta självständigt i projektets arbetsmapp. Ändra inte produktionsserver, publicera inte projektet och återställ inte verklig spelardata utan uttryckligt godkännande.

Ge korta framstegsrapporter på svenska. Prioritera en sammanhängande spelbar version framför många halvfärdiga funktioner.

Börja nu med miljökontroll, aktuell kompatibilitetskontroll och arbetsfördelning mellan agenterna.

MODELLVAL FÖR AGENTER

Använd en mix av modeller utifrån uppgiftens svårighetsgrad.
Kontrollera först vilka modeller och resonemangsnivåer som
faktiskt finns tillgängliga i miljön.

Önskad fördelning:

- Huvudagent och integration:
  GPT-6.1 Sol med High.
  Ansvarar för planering, samordning, arkitektur och integration.

- Spelsystemagent:
  GPT-6.1 Sol med High.
  Implementerar gäng, territorier, rån, ekonomi och progression.

- Polis- och stridsagent:
  GPT-6.1 Sol med High.
  Implementerar polisroll, gripanden, strid, död och räder.

- Infrastruktur- och gränssnittsagent:
  GPT-6.1 Sol med High.
  Implementerar extern MariaDB, NUI, txAdmin-recept och drift.

- Specialist för svåra problem och oberoende granskning:
  GPT-6 Astra med High eller Extra high.
  Granskar särskilt databastransaktioner, dupliceringsskydd,
  behörigheter, samtidighet samt wipe och återställning.
  Använd även denna modell vid svåra integrationsfel.

- Avgränsade rutinuppgifter:
  GPT-6 Luna med Medium.
  Använd för exempelvis dokumentation, språkfiler och enklare
  konfiguration. Kritisk ekonomi- och säkerhetskod ska granskas
  av Sol eller Astra.

Respektera miljöns gräns för samtidiga agenter. Kör uppgifterna
i omgångar när alla roller inte kan vara aktiva samtidigt.
Rollerna behöver inte motsvara permanent aktiva agenter.

Välj modell uttryckligen när verktygen stöder det. Om önskad
modell saknas, använd närmast lämpliga tillgängliga modell
och redovisa avvikelsen. Påstå aldrig att en viss modell
använts om detta inte kan verifieras.

Prioritera Sol för huvuddelen av implementationen, Astra för
svåra beslut och kritisk granskning samt Luna för tydligt
avgränsade rutinuppgifter.

Huvudagenten ansvarar för slutresultatet oavsett vilken modell
som utfört deluppgifterna. Alla kritiska ändringar ska
integreras, granskas och testas.