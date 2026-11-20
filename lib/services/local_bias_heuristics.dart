// Copyright (c) 2026 brokengoose <brokengoose@users.noreply.github.com>
// SPDX-License-Identifier: MIT

import '../models/bias_models.dart';

class _BiasRule {
  const _BiasRule({
    required this.pattern,
    required this.replacement,
    required this.biasType,
    required this.explanation,
  });

  final RegExp pattern;
  final String replacement;
  final String biasType;
  final String explanation;
}

/// Deterministic local heuristic checker for gender-exclusive and racially loaded terms.
/// Ensures pre-post bias checking always works even when the AI endpoint is offline.
class LocalBiasHeuristics {
  LocalBiasHeuristics._();

  static final List<_BiasRule> _rules = [
    _BiasRule(
      pattern: RegExp(r'\bmankind\b', caseSensitive: false),
      replacement: 'humanity',
      biasType: 'Implicit Gender Bias',
      explanation: '"mankind" defaults to male terminology; consider "humanity" or "humankind".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bmanpower\b', caseSensitive: false),
      replacement: 'workforce',
      biasType: 'Implicit Gender Bias',
      explanation: '"manpower" uses male-centered language; consider "workforce" or "staffing".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bchairmen\b', caseSensitive: false),
      replacement: 'chairpersons',
      biasType: 'Implicit Gender Bias',
      explanation: '"chairmen" assumes male leadership; consider "chairpersons" or "chairs".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bchairman\b', caseSensitive: false),
      replacement: 'chairperson',
      biasType: 'Implicit Gender Bias',
      explanation: '"chairman" assumes a male role; consider "chairperson" or "chair".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bpolicemen\b', caseSensitive: false),
      replacement: 'police officers',
      biasType: 'Implicit Gender Bias',
      explanation: '"policemen" is gender-exclusive; consider "police officers".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bpoliceman\b', caseSensitive: false),
      replacement: 'police officer',
      biasType: 'Implicit Gender Bias',
      explanation: '"policeman" is gender-exclusive; consider "police officer".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bfiremen\b', caseSensitive: false),
      replacement: 'firefighters',
      biasType: 'Implicit Gender Bias',
      explanation: '"firemen" is gender-exclusive; consider "firefighters".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bfireman\b', caseSensitive: false),
      replacement: 'firefighter',
      biasType: 'Implicit Gender Bias',
      explanation: '"fireman" is gender-exclusive; consider "firefighter".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bhey\s+guys\b', caseSensitive: false),
      replacement: 'hey everyone',
      biasType: 'Implicit Gender Bias',
      explanation: '"hey guys" uses a male-default plural; consider "hey everyone" or "hey folks".',
    ),
    _BiasRule(
      pattern: RegExp(r'\byou\s+guys\b', caseSensitive: false),
      replacement: 'everyone',
      biasType: 'Implicit Gender Bias',
      explanation: '"you guys" uses a male-default plural; consider "everyone" or "you all".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bhusbands\s+and\s+wives\b', caseSensitive: false),
      replacement: 'spouses and partners',
      biasType: 'Implicit Gender Bias',
      explanation: '"husbands and wives" assumes binary heterosexual couples; consider "spouses and partners".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bwhitelisted\b', caseSensitive: false),
      replacement: 'allowlisted',
      biasType: 'Implicit Racial Bias',
      explanation: '"whitelisted" associates white with permitted/good; consider "allowlisted".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bwhitelist\b', caseSensitive: false),
      replacement: 'allowlist',
      biasType: 'Implicit Racial Bias',
      explanation: '"whitelist" associates white with permitted/good; consider "allowlist".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bblacklisted\b', caseSensitive: false),
      replacement: 'blocklisted',
      biasType: 'Implicit Racial Bias',
      explanation: '"blacklisted" associates black with bad/blocked; consider "blocklisted".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bblacklist\b', caseSensitive: false),
      replacement: 'blocklist',
      biasType: 'Implicit Racial Bias',
      explanation: '"blacklist" associates black with bad/blocked; consider "blocklist".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bmaster\s*[/\-]\s*slave\b', caseSensitive: false),
      replacement: 'primary/replica',
      biasType: 'Implicit Racial Bias',
      explanation: '"master/slave" draws on slavery terminology; consider "primary/replica" or "leader/follower".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bgrandfathered\b', caseSensitive: false),
      replacement: 'legacy-exempted',
      biasType: 'Implicit Racial Bias',
      explanation: '"grandfathered" originates from Jim Crow voter disenfranchisement clauses; consider "legacy-exempted".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbusinessmen\b', caseSensitive: false),
      replacement: 'businesspeople',
      biasType: 'Implicit Gender Bias',
      explanation: '"businessmen" is gender-exclusive; consider "businesspeople".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbusinessman\b', caseSensitive: false),
      replacement: 'businessperson',
      biasType: 'Implicit Gender Bias',
      explanation: '"businessman" is gender-exclusive; consider "businessperson".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bspokesman\b', caseSensitive: false),
      replacement: 'spokesperson',
      biasType: 'Implicit Gender Bias',
      explanation: '"spokesman" is gender-exclusive; consider "spokesperson".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bstewardess\b', caseSensitive: false),
      replacement: 'flight attendant',
      biasType: 'Implicit Gender Bias',
      explanation: '"stewardess" is gendered occupational language; consider "flight attendant".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bman-made\b', caseSensitive: false),
      replacement: 'human-made',
      biasType: 'Implicit Gender Bias',
      explanation: '"man-made" uses male-default wording; consider "human-made" or "artificial".',
    ),
    // Gendered pejoratives, slurs, and stereotypes (longer phrases before base words)
    _BiasRule(
      pattern: RegExp(r'\bsons?\s+of\s+a\s+bitch(?:es)?\b', caseSensitive: false),
      replacement: 'jerk',
      biasType: 'Explicit Gender Bias',
      explanation: '"son of a bitch" uses a gendered slur as an insult; consider neutral wording like "jerk".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbitching\b', caseSensitive: false),
      replacement: 'complaining',
      biasType: 'Explicit Gender Bias',
      explanation: '"bitching" derives from a gendered slur used to demean complaining; consider "complaining" or "venting".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbitched\b', caseSensitive: false),
      replacement: 'complained',
      biasType: 'Explicit Gender Bias',
      explanation: '"bitched" derives from a gendered slur; consider "complained" or "vented".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbitchy\b', caseSensitive: false),
      replacement: 'snappy',
      biasType: 'Explicit Gender Bias',
      explanation: '"bitchy" is a gendered pejorative; consider "snappy", "irritable", or "rude".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbitches\b', caseSensitive: false),
      replacement: 'jerks',
      biasType: 'Explicit Gender Bias',
      explanation: '"bitches" is a gendered slur; consider neutral language.',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbitch\b', caseSensitive: false),
      replacement: 'complain',
      biasType: 'Explicit Gender Bias',
      explanation: '"bitch" is a gendered slur/pejorative; consider neutral wording such as "complain" or "jerk".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bman\s+up\b', caseSensitive: false),
      replacement: 'step up',
      biasType: 'Implicit Gender Bias',
      explanation: '"man up" equates courage or toughness with masculinity; consider "step up" or "be brave".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bgrow\s+a\s+pair\b', caseSensitive: false),
      replacement: 'be brave',
      biasType: 'Implicit Gender Bias',
      explanation: '"grow a pair" equates courage with male anatomy; consider "be brave" or "stand firm".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bballsy\b', caseSensitive: false),
      replacement: 'bold',
      biasType: 'Implicit Gender Bias',
      explanation: '"ballsy" associates boldness with male anatomy; consider "bold" or "gutsy".',
    ),
    _BiasRule(
      pattern: RegExp(r'\b(throw|throws|threw|run|runs|ran|fight|fights|fought|cry|cries|cried)\s+like\s+a\s+girl\b', caseSensitive: false),
      replacement: 'do it weakly',
      biasType: 'Explicit Gender Bias',
      explanation: '"like a girl" used as an insult reinforces gender stereotypes.',
    ),
    _BiasRule(
      pattern: RegExp(r'\bslutty\b', caseSensitive: false),
      replacement: 'provocative',
      biasType: 'Explicit Gender Bias',
      explanation: '"slutty" is a gendered pejorative used to shame women; consider neutral wording.',
    ),
    _BiasRule(
      pattern: RegExp(r'\bsluts?\b', caseSensitive: false),
      replacement: 'person',
      biasType: 'Explicit Gender Bias',
      explanation: '"slut" is a gendered slur used to demean women.',
    ),
    _BiasRule(
      pattern: RegExp(r'\bwhores?\b', caseSensitive: false),
      replacement: 'person',
      biasType: 'Explicit Gender Bias',
      explanation: '"whore" is a gendered slur.',
    ),
    _BiasRule(
      pattern: RegExp(r'\bcunts?\b', caseSensitive: false),
      replacement: 'jerk',
      biasType: 'Explicit Gender Bias',
      explanation: '"cunt" is an explicit gendered slur.',
    ),
    _BiasRule(
      pattern: RegExp(r'\bbimbos?\b', caseSensitive: false),
      replacement: 'person',
      biasType: 'Explicit Gender Bias',
      explanation: '"bimbo" is a derogatory gendered stereotype.',
    ),
    _BiasRule(
      pattern: RegExp(r'\bhousewives\b', caseSensitive: false),
      replacement: 'homemakers',
      biasType: 'Implicit Gender Bias',
      explanation: '"housewives" assumes domestic caregivers are women; consider "homemakers".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bhousewife\b', caseSensitive: false),
      replacement: 'homemaker',
      biasType: 'Implicit Gender Bias',
      explanation: '"housewife" assumes a domestic caregiver is a woman; consider "homemaker".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bsalesmen\b', caseSensitive: false),
      replacement: 'salespeople',
      biasType: 'Implicit Gender Bias',
      explanation: '"salesmen" is gender-exclusive; consider "salespeople".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bsalesman\b', caseSensitive: false),
      replacement: 'salesperson',
      biasType: 'Implicit Gender Bias',
      explanation: '"salesman" is gender-exclusive; consider "salesperson".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bcraftsmen\b', caseSensitive: false),
      replacement: 'artisans',
      biasType: 'Implicit Gender Bias',
      explanation: '"craftsmen" is gender-exclusive; consider "artisans" or "craftspeople".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bcraftsman\b', caseSensitive: false),
      replacement: 'artisan',
      biasType: 'Implicit Gender Bias',
      explanation: '"craftsman" is gender-exclusive; consider "artisan" or "craftsperson".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bfreshmen\b', caseSensitive: false),
      replacement: 'first-year students',
      biasType: 'Implicit Gender Bias',
      explanation: '"freshmen" uses male-default language; consider "first-year students".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bfreshman\b', caseSensitive: false),
      replacement: 'first-year student',
      biasType: 'Implicit Gender Bias',
      explanation: '"freshman" uses male-default language; consider "first-year student".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bwaitresses\b', caseSensitive: false),
      replacement: 'servers',
      biasType: 'Implicit Gender Bias',
      explanation: '"waitresses" is gendered occupational language; consider "servers".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bwaitress\b', caseSensitive: false),
      replacement: 'server',
      biasType: 'Implicit Gender Bias',
      explanation: '"waitress" is gendered occupational language; consider "server".',
    ),
    // Racially and culturally loaded idioms
    _BiasRule(
      pattern: RegExp(r'\bgypped\b', caseSensitive: false),
      replacement: 'cheated',
      biasType: 'Implicit Racial Bias',
      explanation: '"gypped" derives from a derogatory stereotype of Romani people; consider "cheated" or "ripped off".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bgyp\b', caseSensitive: false),
      replacement: 'cheat',
      biasType: 'Implicit Racial Bias',
      explanation: '"gyp" derives from a derogatory stereotype of Romani people; consider "cheat" or "scam".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bpow[\-\s]?wow\b', caseSensitive: false),
      replacement: 'meeting',
      biasType: 'Implicit Racial Bias',
      explanation: '"powwow" appropriates an Indigenous ceremony for casual meetings; consider "meeting" or "huddle".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bspirit\s+animal\b', caseSensitive: false),
      replacement: 'kindred spirit',
      biasType: 'Implicit Racial Bias',
      explanation: '"spirit animal" appropriates Indigenous spiritual traditions; consider "kindred spirit" or "mascot".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bsold\s+down\s+the\s+river\b', caseSensitive: false),
      replacement: 'betrayed',
      biasType: 'Implicit Racial Bias',
      explanation: '"sold down the river" originates from American chattel slavery; consider "betrayed".',
    ),
    _BiasRule(
      pattern: RegExp(r'\buppity\b', caseSensitive: false),
      replacement: 'assertive',
      biasType: 'Implicit Racial Bias',
      explanation: '"uppity" has a racially loaded history used to demean Black people; consider "assertive" or "arrogant".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bcotton[\-\s]picking\b', caseSensitive: false),
      replacement: 'darn',
      biasType: 'Implicit Racial Bias',
      explanation: '"cotton-picking" is rooted in American slavery terminology; consider "darn".',
    ),
    _BiasRule(
      pattern: RegExp(r'\bmaster\s+bedroom\b', caseSensitive: false),
      replacement: 'primary bedroom',
      biasType: 'Implicit Racial Bias',
      explanation: '"master bedroom" carries historical associations with slavery; consider "primary bedroom".',
    ),
  ];

  /// Scans all text-bearing components of a draft and produces findings plus
  /// suggested alternate wording for the main post text if biased terms are found.
  static BiasCheckResult evaluate({
    required BiasCheckInput input,
    List<LinkedPageExcerpt> links = const [],
  }) {
    final findings = <BiasFinding>[];
    final checkedComponents = <String>[];

    String rewrittenPostText = input.postText;
    bool postTextModified = false;

    if (input.postText.trim().isNotEmpty) {
      checkedComponents.add('Post Text');
      final postScan = _scanAndRewrite(input.postText, 'Post Text');
      findings.addAll(postScan.findings);
      if (postScan.modified) {
        rewrittenPostText = postScan.rewritten;
        postTextModified = true;
      }
    }

    if (input.spoilerText.trim().isNotEmpty) {
      checkedComponents.add('Content Warning');
      findings.addAll(
        _scanAndRewrite(input.spoilerText, 'Content Warning').findings,
      );
    }

    for (final attachment in input.attachments) {
      final loc = 'Attachment ${attachment.index}';
      checkedComponents.add(loc);
      if (attachment.altText.trim().isNotEmpty) {
        findings.addAll(_scanAndRewrite(attachment.altText, loc).findings);
      }
    }

    for (final link in links) {
      final loc = 'Link (${link.url})';
      checkedComponents.add(loc);
      final combined = link.toPromptText();
      if (combined.isNotEmpty) {
        findings.addAll(_scanAndRewrite(combined, loc).findings);
      }
    }

    for (final ref in input.referencedStatuses) {
      final loc = ref.locationLabel;
      checkedComponents.add(loc);
      final combined = [
        ref.spoilerText,
        ref.contentText,
        ...ref.mediaAltTexts,
      ].where((s) => s.trim().isNotEmpty).join('\n');
      if (combined.isNotEmpty) {
        findings.addAll(_scanAndRewrite(combined, loc).findings);
      }
    }

    if (findings.isEmpty) {
      return BiasCheckResult(
        hasBias: false,
        summary: 'No racial or gender bias detected via local check.',
        checkedComponents: checkedComponents,
        findings: const [],
        usedLocalFallback: true,
      );
    }

    final checkedLabel = checkedComponents.join(', ');
    final summary =
        'Checked $checkedLabel (offline heuristic check) and found ${findings.length} potential racial or gender bias ${findings.length == 1 ? 'issue' : 'issues'}.';

    return BiasCheckResult(
      hasBias: true,
      summary: summary,
      checkedComponents: checkedComponents,
      findings: findings,
      suggestedAlternateWording: postTextModified ? rewrittenPostText : null,
      usedLocalFallback: true,
    );
  }

  static ({List<BiasFinding> findings, String rewritten, bool modified})
      _scanAndRewrite(String text, String location) {
    final findings = <BiasFinding>[];
    var rewritten = text;
    var modified = false;

    for (final rule in _rules) {
      // Match against the running rewritten text so compound phrases (e.g.
      // "son of a bitch") do not also trigger shorter sub-word rules ("bitch").
      final match = rule.pattern.firstMatch(rewritten);
      if (match != null) {
        findings.add(
          BiasFinding(
            location: location,
            biasType: rule.biasType,
            explanation: rule.explanation,
            excerpt: match.group(0),
          ),
        );
        rewritten = rewritten.replaceAllMapped(rule.pattern, (m) {
          final original = m.group(0) ?? '';
          return _matchCapitalization(original, rule.replacement);
        });
        modified = true;
      }
    }

    return (findings: findings, rewritten: rewritten, modified: modified);
  }

  static String _matchCapitalization(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;
    if (original == original.toUpperCase() && original != original.toLowerCase()) {
      return replacement.toUpperCase();
    }
    if (original[0] == original[0].toUpperCase() &&
        original[0] != original[0].toLowerCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    return replacement;
  }
}
