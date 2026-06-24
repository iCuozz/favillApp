#!/usr/bin/env python3
"""Fix EN translations by deep-copying IT structure + correct translation map."""
import json, os

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ── Translation map: key = text_block_id or option_id → English text ──

T = {}

# ─── s1_crepa ──────────────────────────────────────────
T.update({
    "cr_p0_a_t1": "Deep night. The kitchen is dark. Only the fridge light when Mallow opens the door and stops.",
    "cr_p0_a_t2": "He's holding something. A piece of cloth. The burned shirt — the one Favilla hid at the bottom of her backpack and said she threw away.",
    "cr_p0_a_t3": "I found it this morning. While looking for Lex's charger.",
    "cr_p0_a_t4": "I wasn't trying to snoop. But it was in my hand. And I didn't know what to do with it.",
    "cr_p0_a_t5": "He's not angry. It's worse. He's hurt.",
    "cr_p1_a_t1": "Favilla feels her hands heating up. She hides them behind her back. The gesture doesn't escape Mallow.",
    "cr_p1_a_t2": "I don't want to fight. I just want... to understand. But if you don't want to tell me anything, at least tell me why you can't tell me.",
    "cr_p1_a_t3": "From the playpen, a rustle. Lex is awake.",
    "cr_p1_a_t4": "He doesn't cry. He doesn't laugh. He watches. And for the first time, Favilla sees something in his eyes she's never seen before: sadness.",
    "cr_p1_a_t5": "Lex wanted all of this. His plan was to reveal the truth to dad. But now, seeing mom and dad like this — facing each other, distant — he's not sure he wants it anymore.",
    "cr_p1_a_t6": "Lex. You too. You know too. And you're suffering too.",
    "cr_p2_a_t1": "The air is still. Mallow waits. Lex holds his breath. Favilla's hands burn.",
    "cr_p2_a_t2": "I can turn away. I can lie. I can tell him almost everything.",
    "cr_p2_a_t3": "But nothing will be the same. Whatever I choose.",
    "crepa_choice": "The burned shirt is on the table. Mallow waits. Lex watches.",
    "fidati": "\"I can't explain it. But trust me. Please.\"",
    "silenzio": "\"Let it go. I'm just tired.\"",
    "quasi_confessa": "\"Maybe... I need to tell you something.\"",
    "intro_precaria_a_t1": "Favilla is on the couch. Phone in hand, screen off. She hasn't been able to sleep for hours.",
    "intro_precaria_a_t2": "The secret weighs. Every passing day is another brick. And the house feels it.",
    "intro_precaria_a_t3": "From the playpen, Lex watches her. He can't sleep either. He has the face of someone who wants to help but doesn't know how.",
    "intro_precaria_a_t4": "You're awake too. You feel it too. Sorry, little one.",
    "branch_svolta_a_t1": "I can't explain it. But trust me. Please.",
    "branch_svolta_a_t2": "Mallow looks at her for a long time. Then nods — slowly, as if every millimeter of that nod costs immense effort.",
    "branch_svolta_a_t3": "I trust you. I've always trusted you. But trusting and understanding are two different things.",
    "branch_svolta_a_t4": "Lex, from the playpen, opens his mouth as if to say something. Then closes it. Straightens the owl plushie. He's decided: for tonight, he'll let it go.",
    "branch_silenzio_a_t1": "Let it go. I'm just tired.",
    "branch_silenzio_a_t2": "Mallow says nothing. She's been 'tired' for weeks. He knows it's a lie. But he has no energy left to chase it.",
    "branch_silenzio_a_t3": "He folds the burned shirt. Puts it in a drawer. Doesn't throw it away — keeps it.",
    "branch_silenzio_a_t4": "Lex watches the scene from the playpen. Then closes his eyes. He's stopped waiting. For tonight.",
    "crepa_vera_a_t1": "Favilla speaks. The words come out one after another, without the filter that's kept them safe for weeks.",
    "crepa_vera_a_t2": "That night in the kitchen... when Lex was about to fall. Something happened. I... I wasn't me anymore.",
    "crepa_vera_a_t3": "Mallow listens. He doesn't interrupt. He doesn't say 'what do you mean' — he waits.",
    "crepa_vera_a_t4": "My hair. It lit up. As if... I don't know. As if I had the sun inside.",
    "crepa_vera_a_t5": "Silence. Mallow doesn't understand. But he doesn't laugh. He doesn't judge.",
    "crepa_vera_b_t1": "You're saying... that night something really strange happened? You didn't imagine it?",
    "crepa_vera_b_t2": "I didn't imagine it. Lex saw it. That's why he looks at me like that.",
    "crepa_vera_b_t3": "From the playpen, Lex makes a sound. Not loud. But present. As if to say: 'yes, it's true'.",
    "crepa_vera_b_t4": "Mallow looks at Lex. Then Favilla. He doesn't know what to think. But for the first time, he doesn't ask her to prove it.",
    "crepa_sfumata_a_t1": "That Sunday at the park... I didn't tell you everything. There were things... strange things.",
    "crepa_sfumata_a_t2": "Strange how?",
    "crepa_sfumata_a_t3": "Like... I don't know. Like time skipped a beat. And I was faster.",
    "crepa_sfumata_a_t4": "Mallow furrows his brow. He's not satisfied. But it's something. More than he had before.",
    "crepa_sfumata_a_t5": "Okay. I don't understand. But okay. We'll talk tomorrow.",
    "crepa_bloccata_a_t1": "Mallow... I...",
    "crepa_bloccata_a_t2": "Nothing. It won't come out. Her mouth is dry. The words are there, behind her tongue, but they can't jump.",
    "crepa_bloccata_a_t3": "Mallow waits. Then stops waiting.",
    "crepa_bloccata_a_t4": "Okay. Whenever you're ready.",
    "crepa_bloccata_a_t5": "He doesn't say it with sweetness. He says it with tiredness. The same tiredness Favilla has felt for weeks.",
    "cr_epilogo_a_t1": "Favilla goes back to the bedroom. Mallow is turned the other way. He's not asleep — but he's pretending.",
    "cr_epilogo_a_t2": "Lex sleeps. He's clutching the owl plushie. His plan worked — dad knows something's there — but there's no victory on his face. Just sleep.",
    "cr_epilogo_a_t3": "The secret is intact. But the crack is there. And tomorrow will be another day — with a family that knows it doesn't know.",
    "cr_epilogo_b_t1": "On the other side of the street, a light turns on. One second. Then it turns off.",
    "cr_epilogo_b_t2": "Carmela was awake. She felt something. She doesn't know what. But she'll feel it again.",
    # minigame tier labels
    "Quasi vera.": "Almost true.",
    "Sfumata.": "Faded.",
    "Bloccata.": "Blocked.",
})

# ─── s1_comare ─────────────────────────────────────────
T.update({
    "comare_p0_a_t1": "Afternoon. Mallow is out on an errand. Lex dozes in the playpen. Favilla has ten minutes of silence.",
    "comare_p0_a_t2": "Then the doorbell rings. Once. Brief. Precise.",
    "comare_p0_a_t3": "Favilla looks through the peephole. Carmela. Straw hat. An envelope in hand. Smiling.",
    "comare_p0_a_t4": "No. Not today. Not today.",
    "comare_p1_a_t1": "Through the peephole, Carmela is motionless. The envelope has the Bellow family's name, the downstairs neighbors.",
    "comare_p1_a_t2": "Mrs. Bellow? They delivered your mail wrong. They left it at my place.",
    "comare_p1_a_t3": "Lex opens his eyes. He doesn't cry. He doesn't laugh. He stares at the door.",
    "comare_p1_a_t4": "Lex. Lex stopped laughing. And that scares me more than Carmela.",
    "porta_choice": "Carmela has an envelope. And a smile you don't like.",
    "apri": "Open the door. Let her in.",
    "tieni_chiuso": "\"Thanks, just leave it in the mail slot!\"",
    "intro_sola_a_t1": "Favilla is alone in the living room. Mallow is at work. Lex is asleep. The silence is deafening.",
    "intro_sola_a_t2": "It's been days since she's really talked to anyone. Mallow tries to ask, but she deflects. She's gotten good at deflecting.",
    "intro_sola_a_t3": "Maybe it's better this way. Alone. Safer. More... everything.",
    "intro_sola_a_t4": "Then the doorbell rings. And everything gets worse.",
    "isr_comare_a_t1": "Favilla is on the couch. Ten minutes of silence. But it's not real silence — it's the kind of quiet where every sound from the building makes you flinch.",
    "isr_comare_a_t2": "The secret is so fragile it almost burns inside her. Every time Mallow looks at her, every time Lex makes a weird sound, every time the phone rings — her heart races.",
    "isr_comare_a_t3": "She feels watched even when she's alone. Because maybe she's never alone. Not anymore.",
    "isr_comare_a_t4": "I can't make any more mistakes. Every word, every gesture. One wrong move and everything collapses — Mallow, Lex, normalcy. Everything.",
    "isr_comare_b_t1": "Then the doorbell rings. Once. Brief. Precise.",
    "isr_comare_b_t2": "Favilla already knows who it is. She feels it — literally. A hum under her skin, as if something is pulling the thread the secret hangs from.",
    "isr_comare_b_t3": "Carmela couldn't have picked a worse moment. Or a better one — for her.",
    "isr_comare_b_t4": "She knows I'm fragile. She can smell it. And I'm about to open that door.",
    "branch_apre_a_t1": "Favilla opens the door. Carmela enters with the calm of someone who has crossed that threshold a thousand times. Even though it's the first.",
    "branch_apre_a_t2": "What a cozy home. Warm. Like you.",
    "branch_apre_a_t3": "She looks around. Not like someone admiring décor. Like someone taking notes.",
    "branch_apre_a_t4": "Lex in the playpen is motionless. His eyes follow Carmela as if she were a predator. He's never looked at anyone like this.",
    "branch_apre_b_t1": "Listen. Can I ask you something? It's funny. The other day at the supermarket...",
    "branch_apre_b_t2": "Favilla feels something. A hum. Under her skin. Like when the Sparks activate, but in reverse. As if something were draining her heat.",
    "branch_apre_b_t3": "She's not a neighbor. She's a sensor. And she's reading me.",
    "carmela_dialogo_choice": "Carmela probes. Every word is a hook.",
    "affronta_carmela": "Answer. Calmly.",
    "branch_non_apre_a_t1": "Thanks, just leave it in the mail slot! I'm in the shower!",
    "branch_non_apre_a_t2": "Silence. Then the rustle of the envelope slipping through the slot. Then Carmela's footsteps walking away. Slow. Too slow.",
    "branch_non_apre_a_t3": "Favilla holds her breath. Lex watches her from the playpen. He understood.",
    "branch_non_apre_a_t4": "Not opening was the right choice. But she knows I'm afraid. And fear is what she's looking for.",
    "branch_non_apre_b_t1": "Favilla waits ten seconds. Then goes to the door. The envelope is there — actually addressed to the Bellows.",
    "branch_non_apre_b_t2": "Maybe it was a real excuse. Maybe not. With Carmela you can never know.",
    "branch_non_apre_b_t3": "She'll be back. I gave her what she wanted: proof that I'm hiding.",
    "branch_carmela_bene_a_t1": "Carmela smiles. But it's a different smile — she didn't find what she was looking for.",
    "branch_carmela_bene_a_t2": "Well, I'll let you rest. It was just the mail.",
    "branch_carmela_bene_a_t3": "She turns toward the door. Hesitates for a second. Then leaves. Favilla closes the door and leans against it. Breathes.",
    "branch_carmela_bene_a_t4": "She didn't find anything. Or so she thinks. I dodged it. For now.",
    "branch_carmela_bene_b_t1": "Lex has started playing again. Carmela is gone and he's back to normal. As if the danger has passed.",
    "branch_carmela_bene_b_t2": "Favilla picks him up. He touches her hair. No heat. No Spark. Just mom and baby.",
    "branch_carmela_quasi_a_t1": "Carmela stands up. The tea is still warm. She smiles — a smile that doesn't reach her eyes.",
    "branch_carmela_quasi_a_t2": "You're always so vibrant, Favilla. That's all. Don't be offended.",
    "branch_carmela_quasi_a_t3": "At the door, she stops. Doesn't turn around.",
    "branch_carmela_quasi_a_t4": "Oh, I forgot. Come visit me sometime, when you can. I'd like that.",
    "branch_carmela_quasi_b_t1": "The door closes. Favilla stares at the wood. 'Come visit me.' It wasn't an invitation. It was a summons.",
    "branch_carmela_quasi_b_t2": "Lex from the playpen watches the door. Then watches Favilla. He has the same expression as when he almost hacked the notebook.",
    "branch_carmela_quasi_b_t3": "She sniffed me. She doesn't know what it is, but she knows something's there.",
    "branch_carmela_disastro_a_t1": "Carmela isn't smiling anymore. She stands up. Gets closer. Too close.",
    "branch_carmela_disastro_a_t2": "You carry something big inside you. I can feel it.",
    "branch_carmela_disastro_a_t3": "Favilla feels the hum increase. As if Carmela is draining something from her. Her hair quivers — just once, imperceptibly.",
    "branch_carmela_disastro_a_t4": "Carmela notices. She says nothing. But she notices.",
    "branch_carmela_disastro_b_t1": "At the door, Carmela turns around. Lex stares at her from the playpen. He hasn't looked away. Not once.",
    "branch_carmela_disastro_b_t2": "What a bright child. He... feels it too, doesn't he?",
    "branch_carmela_disastro_b_t3": "She leaves. The door closes. Favilla looks at Lex. Lex looks at the door. Something has changed.",
    "branch_carmela_disastro_b_t4": "She left a mark. I don't know what. But it's in here. And she never really left.",
    "comare_epilogue_a_t1": "Favilla is in the kitchen. The Bellows' envelope is on the table. She still hasn't delivered it.",
    "comare_epilogue_a_t2": "Maybe Carmela never brought it for the Bellows. Maybe it was always an excuse. Maybe nothing is ever what it seems with her.",
    "comare_epilogue_a_t3": "Lex sleeps in the playpen. Restless sleep. As if dreaming of something dark.",
    "comare_epilogue_a_t4": "MISSION COMPLETE — The Nosy Neighbor",
    # minigame tier labels + carmela question labels
    "Insuperabile.": "Unshakeable.",
    "Traballante.": "Wobbly.",
    "Scoperta.": "Exposed.",
})

# ─── s1_prima_conseguenza ──────────────────────────────
T.update({
    "pc_p0_a_t1": "Home. Afternoon. Lex plays on the rug with the GalaxiaMall owl plushie. Favilla folds laundry. Everything normal.",
    "pc_p0_a_t2": "Then Mallow comes out of the study with his phone in hand. He has the expression of someone who just saw something he wasn't supposed to see.",
    "pc_p0_a_t3": "Hey. Have you seen this?",
    "pc_p0_a_t4": "Lex looks up from the owl plushie. He noticed Mallow's tone too. That tone.",
    "pc_p1_a_t1": "On the screen: a TikTok video. Filmed at the park, last Sunday. Shaky framing, 240p, backlit.",
    "pc_p1_a_t2": "A figure moves at impossible speed through the trees. Hair that seems to glow. But the shadows are long and the backlight erases every detail.",
    "pc_p1_a_t3": "Below: 847,000 views. Comments: 'It's a fake', 'I saw her too!', 'Superhero in Nova Tutinia??'",
    "pc_p1_a_t4": "Favilla holds her breath. She recognizes herself. But no one else seems to. For now.",
    "pc_p2_a_t1": "Mallow is standing, phone still in hand. He looks at her as if searching for something in her face.",
    "pc_p2_a_t2": "It was filmed Sunday. At the park. When you lost your purse.",
    "pc_p2_a_t3": "Lex, on the rug, has stopped playing. He stares at Favilla. He recognized the video before even looking at it.",
    "video_choice": "The video plays. The shadows are indistinguishable. But you know.",
    "minimizza": "Shrug. \"Weird. But you know TikTok, everything looks like a ghost.\"",
    "devia": "\"Anyway, Lex did something amazing today...\"",
    "intro_gia_visto_a_t1": "Favilla opens TikTok. The video is still there. More views. New comments. The same indistinguishable shadow.",
    "intro_gia_visto_a_t2": "No one has figured it out yet. But every day that passes, someone could.",
    "intro_gia_visto_a_t3": "I have to be more careful. Much more careful.",
    "branch_minimizza_a_t1": "Favilla swipes past the video with one finger. Shrugs. Smiles — that smile she's learned to make without thinking.",
    "branch_minimizza_a_t2": "Weird. But you know TikTok, everything looks like a ghost. Perspective, backlight, editing.",
    "branch_minimizza_a_t3": "Mallow looks at the video. Then her. Then the video again. Something doesn't add up, but he can't tell what.",
    "branch_minimizza_a_t4": "Yeah. Probably. Still weird though.",
    "branch_minimizza_b_t1": "Mallow goes back to the study. Lex looks at her from the rug with the expression of someone who just watched a mediocre performance.",
    "branch_minimizza_b_t2": "He didn't recognize me. No one will. I just have to... keep going like this.",
    "branch_minimizza_b_t3": "The phone goes dark. But the video is still there. And it will be for a long time.",
    "branch_devia_a_t1": "Favilla changes the subject with the precision of a pilot avoiding an obstacle. Lex. Talk about Lex.",
    "branch_devia_a_t2": "Anyway, Lex did something incredible today. At daycare. He recognized his name written on the board.",
    "branch_devia_a_t3": "Mallow lowers the phone. The video disappears from the screen. Lex looks at her like 'nice move, mom'.",
    "branch_devia_a_t4": "Really? His name? But he's seven months old!",
    "branch_devia_b_t1": "Mallow sits next to her. The conversation derails into how precocious Lex is. The video is forgotten.",
    "branch_devia_b_t2": "But Favilla has the feeling Mallow hasn't really forgotten. Just postponed.",
    "branch_devia_b_t3": "I didn't say anything. But he knows I'm hiding something from him. He's known for weeks.",
    "branch_quasi_confessa_a_t1": "Favilla hesitates. The phone is warm in her hand. The video plays. Then stops playing.",
    "branch_quasi_confessa_a_t2": "That day... I was there. At the park. I saw everything.",
    "branch_quasi_confessa_a_t3": "Mallow stops the spoon mid-air. The seconds stretch. Lex, on the rug, is motionless as a statue.",
    "branch_quasi_confessa_a_t4": "What did you see?",
    "branch_quasi_confessa_b_t1": "The thief. I saw him. He ran toward the grove. I was there when it happened.",
    "branch_quasi_confessa_b_t2": "Half-truth. The part Mallow can accept. The other half — the speed, the hair, the light — stays buried.",
    "branch_quasi_confessa_b_t3": "Why didn't you tell me?",
    "branch_quasi_confessa_b_t4": "Because... I don't know. Maybe I was afraid you'd worry.",
    "branch_quasi_confessa_b_t5": "Lex smiles. He got what he wanted. Not the whole truth. But a step.",
    "pc_epilogue_a_t1": "Favilla is in the bedroom. The phone is on the nightstand, screen off. But the video is still there, in her mind.",
    "pc_epilogue_a_t2": "A comment under the video: 'Looks like a superhero.' Another: 'Superhero my ass, it's Photoshop.' A third: 'I live in Nova Tutinia and let me tell you, nothing is normal here.'",
    "pc_epilogue_a_t3": "No one knows. No one can know. But the world has started watching.",
    "pc_epilogue_a_t4": "MISSION COMPLETE — The First Consequence",
})

# ─── s1_cena_famiglia ──────────────────────────────────
T.update({
    "cena_p0_a_t1": "Evening. The kitchen smells of butter and eggs. Mallow is at the stove with the air of someone about to reveal a family secret.",
    "cena_p0_a_t2": "Two eggs. You crack them like this, put cheese inside, fold them like a calzone. You fry them. It's called 'calzuovo.' My grandmother's recipe.",
    "cena_p0_a_t3": "Lex stares at him from the high chair. Not at the calzuovo. At him. With detective eyes.",
    "cena_p0_a_t4": "Calzuovo. I like it. Sounds like something you eat and then go into battle.",
    "cena_p0_a_t5": "Exactly. It's the warriors' dish. Or at least hungry programmers'.",
    "cena_p1_a_t1": "The calzuovo arrives at the table. Mallow serves it with the pride of a Michelin-starred chef. Lex looks at the plate. Then at Favilla. Then at the plate again.",
    "cena_p1_a_t2": "He's plotting. I can tell. He has the same face as in the pasta aisle.",
    "cena_p1_a_t3": "Lex pushes the plate away. He doesn't eat. He squints. Points his little finger toward Favilla. Then toward Mallow. Back and forth.",
    "cena_p1_a_t4": "What's up with you tonight? You don't like calzuovo?",
    "cena_p1_a_t5": "It's not the calzuovo. It's his mother. He's trying to tell you.",
    "cena_p2_a_t1": "Lex is now staging a small sabotage. The spoon falls. Then the cup. Then the bib. One object at a time, with increasing emphasis on the target: Favilla.",
    "cena_p2_a_t2": "Mallow looks at him. Then at Favilla. Then back at Lex. Something clicks.",
    "cena_p2_a_t3": "You know what's weird? For a few weeks now, every time something... strange happens, he does exactly this.",
    "cena_p2_a_t4": "He knows. He doesn't know. But he feels it. And Lex is serving it to him on a silver platter.",
    "cena_p3_a_t1": "Mallow puts down his fork. Dinner is halfway through. Lex has stopped throwing objects and is staring at Favilla with unprecedented intensity.",
    "cena_p3_a_t2": "Favilla. There's something you're not telling me.",
    "cena_p3_a_t3": "He's not angry. He's... gentle. As if he's asking permission to know.",
    "cena_choice": "Mallow looks at you. Lex too. Dinner is a powder keg.",
    "confessa_piccolo": "\"Mallow... I need to tell you something. That Sunday at the park...\"",
    "facciata": "\"Lex, eat. Mallow, this is delicious. Everything's fine.\"",
    "umorismo": "\"Mallow, your son is trying to direct a movie. Or maybe an exposé.\"",
    "distrai_lex": "You look at Lex. He has crayons in hand. He's drawing something.",
    "intro_calda_a_t1": "Mallow spent the afternoon at the stove. Calzuovo isn't just a recipe — it's a declaration. When Mallow cooks, he's saying what he can't put into words.",
    "intro_calda_a_t2": "Favilla knows. And it's exactly this warmth she risks losing if one day he finds out everything at the wrong time, in the wrong way.",
    "intro_calda_a_t3": "I thought that after the week you've had... you deserved a real dinner.",
    "intro_calda_a_t4": "Lex from the high chair watches the scene. He's calculating. Tonight, dad is on his side.",
    "branch_confessa_a_t1": "Favilla puts down her fork. Lex stops breathing — or so it seems, for a seven-and-a-half-month-old.",
    "branch_confessa_a_t2": "That Sunday at the park... something happened. I don't know how to explain it. Even to myself.",
    "branch_confessa_a_t3": "Mallow says nothing. He takes her hand. He waits.",
    "branch_confessa_a_t4": "Whenever you're ready, I'm here. I'm not going anywhere.",
    "branch_confessa_a_t5": "Not the whole truth. But a piece of it. Enough for tonight.",
    "branch_confessa_b_t1": "Lex releases his breath. Then smiles — that conspiratorial two-tooth smile that says 'finally'.",
    "branch_confessa_b_t2": "The calzuovo is almost cold. But Mallow's hand is still there, on top of hers.",
    "branch_confessa_b_t3": "Let's eat, before it gets cold. Then you can tell me the rest.",
    "branch_facciata_a_t1": "Favilla smiles. A well-practiced smile. She changes the subject with the fluidity of someone who's done it many times before.",
    "branch_facciata_a_t2": "Everything's fine, really. Just tired. Corvi, the inspection. Heavy week. But this calzuovo is a miracle.",
    "branch_facciata_a_t3": "Mallow nods. But he hasn't stopped looking at her. Lex snorts — frustrated, theatrical.",
    "branch_facciata_a_t4": "I lied to him again. And Lex knows. And he's angry at me.",
    "branch_facciata_b_t1": "Mallow goes back to eating. Talks about work, about a new JavaScript library. The evening derails into normalcy.",
    "branch_facciata_b_t2": "But Lex won't look at her anymore. He has his arms crossed on the high chair. Seven months old and already capable of holding a grudge.",
    "branch_facciata_b_t3": "I kept the secret. But I lost something with my son. I'll make it up tomorrow. Or maybe I won't.",
    "branch_umorismo_a_t1": "Favilla looks at Lex. Then at Mallow. Then bursts out laughing — that real, full laugh she's almost forgotten she had.",
    "branch_umorismo_a_t2": "Mallow, look at him. He has the face of someone trying to make us divorce. He's our tiny villain.",
    "branch_umorismo_a_t3": "Lex makes a face — a kind of raspberry that sounds like 'I'm not a secret agent but I'm working on it'.",
    "branch_umorismo_a_t4": "He has more charisma than me. I say it with pride and a little fear.",
    "branch_umorismo_b_t1": "All three of them laugh at the same moment. The calzuovo is finished, but it doesn't matter. For an instant, it's just a family having dinner.",
    "branch_umorismo_b_t2": "Lex falls asleep shortly after, his head drooping. But he's smiling. He won something, even if he doesn't know what yet.",
    "branch_umorismo_b_t3": "Tomorrow everything will be complicated again. But not tonight. Tonight is ours.",
    "disegno_innocuo_a_t1": "Lex looks at his own drawing. The mom with fire hair now has normal hair. The sparks have become... little stars. Generic. Harmless.",
    "disegno_innocuo_a_t2": "His masterpiece has been modified. By someone who had a gray crayon and suspicious knowledge of his plan.",
    "disegno_innocuo_a_t3": "Lex stares at Favilla with the expression of someone who just lost a chess match against their own mother.",
    "disegno_innocuo_a_t4": "What a nice drawing! Is that us? Look, that's you, those are me and mom.",
    "disegno_innocuo_b_t1": "Yes. The three of us.",
    "disegno_innocuo_b_t2": "Mallow smiles. Lex crosses his arms on the high chair. Defeated. For now.",
    "disegno_innocuo_b_t3": "The calzuovo is almost finished. The drawing is harmless. And Lex has learned that mom is faster than him even at the dinner table.",
    "disegno_innocuo_b_t4": "Nice try, little one. But I win tonight.",
    "disegno_quasi_a_t1": "Favilla quickly modifies what she can. The result is a strange drawing: a figure with half-yellow, half-gray hair. A smile erased and redrawn.",
    "disegno_quasi_a_t2": "A crayon rolls away. Lex follows it with his eyes. Favilla picks it up before he can point at it.",
    "disegno_quasi_a_t3": "What's that? Let me see.",
    "disegno_quasi_a_t4": "A self-portrait by Lex. Abstract. He's talented.",
    "disegno_quasi_b_t1": "Lex glares at her. Mallow laughs:",
    "disegno_quasi_b_t2": "He's talented.",
    "disegno_quasi_b_t3": "But he hesitated a second too long before laughing. That second in which he looked at the drawing more carefully than necessary.",
    "disegno_quasi_b_t4": "He didn't understand. But he felt there's something to understand. Tomorrow he'll think about it again.",
    "disegno_visto_a_t1": "Mallow approaches while Favilla still has the crayon in hand. It's too late.",
    "disegno_visto_a_t2": "Who's that?",
    "disegno_visto_a_t3": "He points to the fire hair. Favilla takes the sheet. Crumples it.",
    "disegno_visto_a_t4": "Nothing. Kid stuff.",
    "disegno_visto_b_t1": "But Mallow doesn't look away. Lex smiles — he won.",
    "disegno_visto_b_t2": "They look like... glowing hair. Like in the video.",
    "disegno_visto_b_t3": "The silence lasts a second. Lex looks at Mallow. Mallow looks at Favilla. Favilla looks at the crumpled drawing.",
    "disegno_visto_b_t4": "He connected the drawing to the video. My son just screwed me. With a crayon.",
    "cena_epilogue_a_t1": "Lex sleeps in his room. Mallow does the dishes. Favilla watches him from behind, leaning against the doorframe.",
    "cena_epilogue_a_t2": "She says nothing. He doesn't turn around. But he raises a soapy hand in a gesture that means 'I know you're there'.",
    "cena_epilogue_a_t3": "The secret is still there. But tonight it's lighter. Or at least it seems that way.",
    "cena_epilogue_a_t4": "MISSION COMPLETE — Family Dinner",
    # minigame tier labels
    "Innocuo.": "Harmless.",
    "Quasi innocuo.": "Almost harmless.",
    "Visto.": "Seen.",
})

# ─── s1_prima_conseguenza: quasi_confessa option fix ──
T["quasi_confessa_prima"] = "You hesitate. You look at the video. \"That day... I was there.\""

# ── Apply translations ─────────────────────────────────
def translate_episode(ep_id):
    src = f"assets/data/quests/s1/{ep_id}.json"
    dst = f"assets/data/quests/s1/{ep_id}.en.json"

    with open(src) as f:
        data = json.load(f)

    translated = 0

    # Walk and translate all text fields
    def walk(obj):
        nonlocal translated
        if isinstance(obj, dict):
            # text_blocks: translate text by id
            if "id" in obj and "text" in obj and "type" in obj:
                tb_id = obj["id"]
                if tb_id in T:
                    obj["text"] = T[tb_id]
                    translated += 1
            # options: translate label and hint by id
            if "id" in obj and "label" in obj and "stat_effects" in obj:
                opt_id = obj["id"]
                if opt_id in T:
                    obj["label"] = T[opt_id]
                    translated += 1
            # choice prompts
            if "id" in obj and "prompt" in obj and "options" in obj:
                choice_id = obj["id"]
                if choice_id in T:
                    obj["prompt"] = T[choice_id]
                    translated += 1
            # minigame tier labels
            if "label" in obj and "min" in obj and "goto_branch" in obj:
                label = obj["label"]
                if label in T:
                    obj["label"] = T[label]
                    translated += 1
            # carmela_dialogo questions
            if "text" in obj and "timer" in obj and "options" in obj:
                qtext = obj["text"]
                if qtext in T:
                    obj["text"] = T[qtext]
                    translated += 1
                for qopt in obj.get("options", []):
                    qopt_label = qopt.get("label", "")
                    if qopt_label in T:
                        qopt["label"] = T[qopt_label]
                        translated += 1
            for k, v in obj.items():
                walk(v)
        elif isinstance(obj, list):
            for item in obj:
                walk(item)

    walk(data)

    with open(dst, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"  ✅ {ep_id}.en.json ({translated} texts translated)")

for ep in ["s1_crepa", "s1_comare", "s1_prima_conseguenza", "s1_cena_famiglia"]:
    translate_episode(ep)

print("\nDone.")
