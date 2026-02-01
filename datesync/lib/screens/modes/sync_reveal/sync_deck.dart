import 'sync_models.dart';

class SyncDeck {
  // NOTE:
  // - Simple language (EN/TR)
  // - Options are always "Me / You" to keep gameplay fast.
  // - Bonus = if match
  // - Explain = if mismatch (5 words rule)
  static const questions = <SyncQuestion>[
    // -------------------------
    // 1) Jealousy
    // -------------------------
    SyncQuestion(
      promptEn: 'Who gets jealous more easily?',
      promptTr: 'Kim daha kolay kıskanır?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: 10 seconds eye contact. No laughing.',
        'Bonus: Say 1 thing you trust about me.',
        'Bonus: Give a 7-word compliment.',
        'Bonus: Hold hands for 15 seconds.',
      ],
      bonusTr: [
        'Bonus: 10 saniye göz teması. Gülmek yok.',
        'Bonus: Bende güvendiğin 1 şeyi söyle.',
        'Bonus: 7 kelimelik iltifat et.',
        'Bonus: 15 saniye el ele tutuş.',
      ],
      explainEn: [
        'Explain your choice in 5 words.',
        'Defend your pick in 5 words.',
        'Say it in 5 words (no more).',
      ],
      explainTr: [
        'Seçimini 5 kelimeyle açıkla.',
        'Seçimini 5 kelimeyle savun.',
        '5 kelimeyle söyle (fazla yok).',
      ],
    ),

    // -------------------------
    // 2) Sleep
    // -------------------------
    SyncQuestion(
      promptEn: 'Who falls asleep first?',
      promptTr: 'Kim daha önce uyuyakalır?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Do a cute “good night” voice.',
        'Bonus: Say “good night” in a funny way.',
        'Bonus: Give a 5-word bedtime compliment.',
      ],
      bonusTr: [
        'Bonus: Tatlı bir “iyi geceler” sesi yap.',
        'Bonus: Komik bir şekilde “iyi geceler” de.',
        'Bonus: 5 kelimelik uyku iltifatı et.',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Tell the story in 5 words.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        '5 kelimeyle anlat.',
      ],
    ),

    // -------------------------
    // 3) Drama level
    // -------------------------
    SyncQuestion(
      promptEn: 'Who is more dramatic?',
      promptTr: 'Kim daha dramatik?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Do a 5-second “drama pose”.',
        'Bonus: Say my name like a movie scene.',
        'Bonus: Give a dramatic compliment.',
      ],
      bonusTr: [
        'Bonus: 5 saniye “drama pozu” yap.',
        'Bonus: Adımı film sahnesi gibi söyle.',
        'Bonus: Dramatik bir iltifat et.',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Give your reason in 5 words.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        'Sebebini 5 kelimeyle söyle.',
      ],
    ),

    // -------------------------
    // 4) Who texts back faster
    // -------------------------
    SyncQuestion(
      promptEn: 'Who replies faster?',
      promptTr: 'Kim daha hızlı cevap yazar?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Send a 1-line sweet message (show it).',
        'Bonus: Type “I miss you” in 3 seconds.',
        'Bonus: Give a 5-word “texting style” compliment.',
      ],
      bonusTr: [
        'Bonus: 1 cümle tatlı mesaj yaz (göster).',
        'Bonus: 3 saniyede “özledim” yaz.',
        'Bonus: 5 kelimeyle “mesaj tarzı” iltifatı et.',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Say why in 5 words.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        'Nedenini 5 kelimeyle söyle.',
      ],
    ),

    // -------------------------
    // 5) Who is more clingy
    // -------------------------
    SyncQuestion(
      promptEn: 'Who is more clingy (in a cute way)?',
      promptTr: 'Kim daha yapışık (tatlı şekilde)?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Give a 10-second hug (if you want).',
        'Bonus: Say “I like you” in 3 styles.',
        'Bonus: Hold my arm for 10 seconds.',
      ],
      bonusTr: [
        'Bonus: 10 saniye sarıl (istersen).',
        'Bonus: 3 farklı tarzda “senden hoşlanıyorum” de.',
        'Bonus: 10 saniye koluma gir.',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Be honest: 5 words.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        'Dürüst ol: 5 kelime.',
      ],
    ),

    // -------------------------
    // 6) Who would win an argument
    // -------------------------
    SyncQuestion(
      promptEn: 'Who would win an argument?',
      promptTr: 'Tartışmada kim kazanır?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Do a 5-second “victory dance”.',
        'Bonus: Say one thing you respect about me.',
        'Bonus: Shake hands like a peace treaty.',
      ],
      bonusTr: [
        'Bonus: 5 saniye “zafer dansı” yap.',
        'Bonus: Bende saygı duyduğun 1 şeyi söyle.',
        'Bonus: Barış anlaşması gibi el sıkış.',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Give 5-word evidence.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        '5 kelimelik kanıt sun.',
      ],
    ),

    // -------------------------
    // 7) Who is more romantic
    // -------------------------
    SyncQuestion(
      promptEn: 'Who is more romantic?',
      promptTr: 'Kim daha romantik?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Say one romantic sentence right now.',
        'Bonus: Give a 7-word compliment.',
        'Bonus: Whisper one sweet thing.',
      ],
      bonusTr: [
        'Bonus: Şu an 1 romantik cümle kur.',
        'Bonus: 7 kelimelik iltifat et.',
        'Bonus: 1 tatlı şey fısılda.',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Say why in 5 words.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        'Nedenini 5 kelimeyle söyle.',
      ],
    ),

    // -------------------------
    // 8) Who would survive a zombie movie longer
    // -------------------------
    SyncQuestion(
      promptEn: 'Who would survive a zombie movie longer?',
      promptTr: 'Zombi filminde kim daha uzun yaşar?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Act your escape plan for 5 seconds.',
        'Bonus: Make a zombie sound (3 seconds).',
        'Bonus: Pick a “team role”: leader or genius.',
      ],
      bonusTr: [
        'Bonus: 5 saniye kaçış planını canlandır.',
        'Bonus: 3 saniye zombi sesi yap.',
        'Bonus: “Takım rolü” seç: lider mi dahi mi?',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Give your reason in 5 words.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        'Sebebini 5 kelimeyle söyle.',
      ],
    ),

    // -------------------------
    // 9) Who is more patient
    // -------------------------
    SyncQuestion(
      promptEn: 'Who is more patient?',
      promptTr: 'Kim daha sabırlı?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Stay silent for 5 seconds (together).',
        'Bonus: Say one thing you forgive easily.',
        'Bonus: Give a calm, sweet smile for 3 seconds.',
      ],
      bonusTr: [
        'Bonus: 5 saniye sessiz kal (birlikte).',
        'Bonus: Kolay affettiğin 1 şeyi söyle.',
        'Bonus: 3 saniye sakin tatlı gülümse.',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Why? 5 words only.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        'Neden? Sadece 5 kelime.',
      ],
    ),

    // -------------------------
    // 10) Who plans dates better
    // -------------------------
    SyncQuestion(
      promptEn: 'Who plans dates better?',
      promptTr: 'Kim daha iyi randevu planlar?',
      optionsEn: ['Me', 'You'],
      optionsTr: ['Ben', 'Sen'],
      bonusEn: [
        'Bonus: Plan a 1-minute date idea now.',
        'Bonus: Choose: café / walk / movie / home.',
        'Bonus: Say the first place you’d take me.',
      ],
      bonusTr: [
        'Bonus: Şimdi 1 dakikalık mini randevu planı yap.',
        'Bonus: Seç: kafe / yürüyüş / film / ev.',
        'Bonus: Beni götüreceğin ilk yeri söyle.',
      ],
      explainEn: [
        'Explain in 5 words.',
        'Say why in 5 words.',
      ],
      explainTr: [
        '5 kelimeyle açıkla.',
        'Nedenini 5 kelimeyle söyle.',
      ],
    ),
  ];
}
