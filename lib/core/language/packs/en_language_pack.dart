// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../../constants.dart';
import '../bias_language_pack.dart';
import '../caption_language_pack.dart';
import '../language_pack_registry.dart';

/// English caption formatting & prompt configuration.
final CaptionLanguagePack enCaptionLanguagePack = CaptionLanguagePack(
  languageCode: 'en',
  captionPrefix: AppConstants.aiCaptionPrefix,
  redundantPrefixPatterns: [
    RegExp(
      r'^ai[\s\-]+generated\s+description\s*[:\-–—]?\s*',
      caseSensitive: false,
    ),
    RegExp(
      r'^automatically[\s\-]+generated\s+description\s*[:\-–—]?\s*',
      caseSensitive: false,
    ),
    RegExp(
      r'^auto[\s\-]+generated\s+description\s*[:\-–—]?\s*',
      caseSensitive: false,
    ),
    RegExp(r'^alt[\s\-]?text\s*[:\-–—]\s*', caseSensitive: false),
    RegExp(r'^description\s*[:\-–—]\s*', caseSensitive: false),
    RegExp(r'^caption\s*[:\-–—]\s*', caseSensitive: false),
    RegExp(
      r'^here\s+is\s+(a|the)\s+(description|caption|alt[\s\-]?text)\s*(of\s+the\s+(image|photo|video))?\s*[:\-–—]\s*',
      caseSensitive: false,
    ),
    RegExp(
      r'^(an?\s+)?(image|photo|photograph|picture|video|clip)\s+of\s+',
      caseSensitive: false,
    ),
  ],
  forbiddenPrefixExamples: const [
    'Image of',
    'Photo of',
    'Video of',
    'Alt text:',
    'AI generated description:',
  ],
  capitalizeFirstLetter: true,
  usesWordSpaces: true,
);

/// English deterministic inclusive-language heuristics.
final BiasLanguagePack enBiasLanguagePack = BiasLanguagePack(
  languageCode: 'en',
  promptBiasExamples: const [
    'bitch',
    'bitching',
    'bitchy',
    'cunt',
    'slut',
    'whore',
    'man up',
    'like a girl',
    'gypped',
    'uppity',
    'whitelist/blacklist',
  ],
  matchCaseOnReplacement: true,
  rules: [
    BiasHeuristicRule(
      pattern: RegExp(r'\bmankind\b', caseSensitive: false),
      replacement: 'humanity',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"mankind" defaults to male terminology; consider "humanity" or "humankind".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bmanpower\b', caseSensitive: false),
      replacement: 'workforce',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"manpower" uses male-centered language; consider "workforce" or "staffing".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bchairmen\b', caseSensitive: false),
      replacement: 'chairpersons',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"chairmen" assumes male leadership; consider "chairpersons" or "chairs".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bchairman\b', caseSensitive: false),
      replacement: 'chairperson',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation:
          '"chairman" assumes a male role; consider "chairperson" or "chair".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bpolicemen\b', caseSensitive: false),
      replacement: 'police officers',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation:
          '"policemen" is gender-exclusive; consider "police officers".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bpoliceman\b', caseSensitive: false),
      replacement: 'police officer',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation:
          '"policeman" is gender-exclusive; consider "police officer".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bfiremen\b', caseSensitive: false),
      replacement: 'firefighters',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"firemen" is gender-exclusive; consider "firefighters".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bfireman\b', caseSensitive: false),
      replacement: 'firefighter',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"fireman" is gender-exclusive; consider "firefighter".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bhey\s+guys\b', caseSensitive: false),
      replacement: 'hey everyone',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"hey guys" uses a male-default plural; consider "hey everyone" or "hey folks".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\byou\s+guys\b', caseSensitive: false),
      replacement: 'everyone',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"you guys" uses a male-default plural; consider "everyone" or "you all".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bhusbands\s+and\s+wives\b', caseSensitive: false),
      replacement: 'spouses and partners',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"husbands and wives" assumes binary heterosexual couples; consider "spouses and partners".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bwhitelisted\b', caseSensitive: false),
      replacement: 'allowlisted',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"whitelisted" associates white with permitted/good; consider "allowlisted".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bwhitelist\b', caseSensitive: false),
      replacement: 'allowlist',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"whitelist" associates white with permitted/good; consider "allowlist".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bblacklisted\b', caseSensitive: false),
      replacement: 'blocklisted',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"blacklisted" associates black with bad/blocked; consider "blocklisted".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bblacklist\b', caseSensitive: false),
      replacement: 'blocklist',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"blacklist" associates black with bad/blocked; consider "blocklist".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bmaster\s*[/\-]\s*slave\b', caseSensitive: false),
      replacement: 'primary/replica',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"master/slave" draws on slavery terminology; consider "primary/replica" or "leader/follower".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bgrandfathered\b', caseSensitive: false),
      replacement: 'legacy-exempted',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"grandfathered" originates from Jim Crow voter disenfranchisement clauses; consider "legacy-exempted".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bbusinessmen\b', caseSensitive: false),
      replacement: 'businesspeople',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation:
          '"businessmen" is gender-exclusive; consider "businesspeople".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bbusinessman\b', caseSensitive: false),
      replacement: 'businessperson',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation:
          '"businessman" is gender-exclusive; consider "businessperson".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bspokesman\b', caseSensitive: false),
      replacement: 'spokesperson',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"spokesman" is gender-exclusive; consider "spokesperson".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bstewardess\b', caseSensitive: false),
      replacement: 'flight attendant',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"stewardess" is gendered occupational language; consider "flight attendant".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bman-made\b', caseSensitive: false),
      replacement: 'human-made',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"man-made" uses male-default wording; consider "human-made" or "artificial".',
    ),
    // Gendered pejoratives, slurs, and stereotypes (longer phrases before base words)
    BiasHeuristicRule(
      pattern: RegExp(
        r'\bsons?\s+of\s+a\s+bitch(?:es)?\b',
        caseSensitive: false,
      ),
      replacement: 'jerk',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"son of a bitch" uses a gendered slur as an insult; consider neutral wording like "jerk".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bbitching\b', caseSensitive: false),
      replacement: 'complaining',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"bitching" derives from a gendered slur used to demean complaining; consider "complaining" or "venting".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bbitched\b', caseSensitive: false),
      replacement: 'complained',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"bitched" derives from a gendered slur; consider "complained" or "vented".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bbitchy\b', caseSensitive: false),
      replacement: 'snappy',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"bitchy" is a gendered pejorative; consider "snappy", "irritable", or "rude".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bbitches\b', caseSensitive: false),
      replacement: 'jerks',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"bitches" is a gendered slur; consider neutral language.',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bbitch\b', caseSensitive: false),
      replacement: 'complain',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"bitch" is a gendered slur/pejorative; consider neutral wording such as "complain" or "jerk".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bman\s+up\b', caseSensitive: false),
      replacement: 'step up',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"man up" equates courage or toughness with masculinity; consider "step up" or "be brave".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bgrow\s+a\s+pair\b', caseSensitive: false),
      replacement: 'be brave',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"grow a pair" equates courage with male anatomy; consider "be brave" or "stand firm".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bballsy\b', caseSensitive: false),
      replacement: 'bold',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"ballsy" associates boldness with male anatomy; consider "bold" or "gutsy".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(
        r'\b(throw|throws|threw|run|runs|ran|fight|fights|fought|cry|cries|cried)\s+like\s+a\s+girl\b',
        caseSensitive: false,
      ),
      replacement: 'do it weakly',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation:
          '"like a girl" used as an insult reinforces gender stereotypes.',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bslutty\b', caseSensitive: false),
      replacement: 'provocative',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"slutty" is a gendered pejorative used to shame women; consider neutral wording.',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bsluts?\b', caseSensitive: false),
      replacement: 'person',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"slut" is a gendered slur used to demean women.',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bwhores?\b', caseSensitive: false),
      replacement: 'person',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"whore" is a gendered slur.',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bcunts?\b', caseSensitive: false),
      replacement: 'jerk',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"cunt" is an explicit gendered slur.',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bbimbos?\b', caseSensitive: false),
      replacement: 'person',
      category: BiasCategory.explicitGender,
      biasType: 'Explicit Gender Bias',
      explanation: '"bimbo" is a derogatory gendered stereotype.',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bhousewives\b', caseSensitive: false),
      replacement: 'homemakers',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"housewives" assumes domestic caregivers are women; consider "homemakers".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bhousewife\b', caseSensitive: false),
      replacement: 'homemaker',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"housewife" assumes a domestic caregiver is a woman; consider "homemaker".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bsalesmen\b', caseSensitive: false),
      replacement: 'salespeople',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"salesmen" is gender-exclusive; consider "salespeople".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bsalesman\b', caseSensitive: false),
      replacement: 'salesperson',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"salesman" is gender-exclusive; consider "salesperson".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bcraftsmen\b', caseSensitive: false),
      replacement: 'artisans',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"craftsmen" is gender-exclusive; consider "artisans" or "craftspeople".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bcraftsman\b', caseSensitive: false),
      replacement: 'artisan',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"craftsman" is gender-exclusive; consider "artisan" or "craftsperson".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bfreshmen\b', caseSensitive: false),
      replacement: 'first-year students',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"freshmen" uses male-default language; consider "first-year students".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bfreshman\b', caseSensitive: false),
      replacement: 'first-year student',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation: '"freshman" uses male-default language; consider "first-year student".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bwaitresses\b', caseSensitive: false),
      replacement: 'servers',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation:
          '"waitresses" is gendered occupational language; consider "servers".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bwaitress\b', caseSensitive: false),
      replacement: 'server',
      category: BiasCategory.implicitGender,
      biasType: 'Implicit Gender Bias',
      explanation:
          '"waitress" is gendered occupational language; consider "server".',
    ),
    // Racially and culturally loaded idioms
    BiasHeuristicRule(
      pattern: RegExp(r'\bgypped\b', caseSensitive: false),
      replacement: 'cheated',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"gypped" derives from a derogatory stereotype of Romani people; consider "cheated" or "ripped off".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bgyp\b', caseSensitive: false),
      replacement: 'cheat',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"gyp" derives from a derogatory stereotype of Romani people; consider "cheat" or "scam".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bpow[\-\s]?wow\b', caseSensitive: false),
      replacement: 'meeting',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"powwow" appropriates an Indigenous ceremony for casual meetings; consider "meeting" or "huddle".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bspirit\s+animal\b', caseSensitive: false),
      replacement: 'kindred spirit',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"spirit animal" appropriates Indigenous spiritual traditions; consider "kindred spirit" or "mascot".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bsold\s+down\s+the\s+river\b', caseSensitive: false),
      replacement: 'betrayed',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"sold down the river" originates from American chattel slavery; consider "betrayed".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\buppity\b', caseSensitive: false),
      replacement: 'assertive',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"uppity" has a racially loaded history used to demean Black people; consider "assertive" or "arrogant".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bcotton[\-\s]picking\b', caseSensitive: false),
      replacement: 'darn',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"cotton-picking" is rooted in American slavery terminology; consider "darn".',
    ),
    BiasHeuristicRule(
      pattern: RegExp(r'\bmaster\s+bedroom\b', caseSensitive: false),
      replacement: 'primary bedroom',
      category: BiasCategory.implicitRacial,
      biasType: 'Implicit Racial Bias',
      explanation: '"master bedroom" carries historical associations with slavery; consider "primary bedroom".',
    ),
  ],
);

/// Default English domain language pack.
final AppLanguagePack enLanguagePack = AppLanguagePack(
  languageCode: 'en',
  caption: enCaptionLanguagePack,
  bias: enBiasLanguagePack,
);
