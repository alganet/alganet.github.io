<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-02-22-23-Aproveitando-Atributos-com-Respect-Validation-e-Laravel.pt
date: February 22, 2026
author: Alexandre Gomes Gaigalas
lang: en
---

# Leveraging Attributes With Respect\Validation and Laravel

The full example for this blog post is [available on GitHub](https://github.com/alganet/attributes-laravel-validation).

## Context

Validation logic often ends up distributed across request rules, controller checks, model helpers, and serializers. In that arrangement, constraints for the same field can diverge over time.

This example uses a single domain object as the source of truth for constraints and payload mapping, then integrates that object into Laravel request handling and persistence.

## Design Objective

The objective is to keep one authoritative definition for:
- domain constraints
- validation messages
- persistence/output field mapping


`PitchDraft` is that authoritative definition.

## Domain Contract

`PitchDraft` declares constraints directly on typed constructor parameters with Respect attributes.

```
final readonly class PitchDraft
{
    public function __construct(
        #[Named('Speaker Name', new AllOf(new StringType, new Length(new Between(4, 60))))]
        public string $speaker_name,

        #[Named('Speaker Email', new Email)]
        public string $speaker_email,

        #[Named('Talk Title', new ShortCircuit(new Length(new Between(12, 90)), new Contains('Laravel')))]
        public string $talk_title,

        #[Named('Talk Duration', new AllOf(new IntVal, new Between(20, 45)))]
        public int $talk_duration_minutes,

        #[Named('Skill Level', new Templated('Skill level must be either {{haystack|list:or}}.', new In(['intermediate', 'advanced']))) ]
        public string $skill_level,
    ) {}
}

```

This keeps rule composition explicit (`AllOf`, `ShortCircuit`, `Between`, `Each`) and localizes message customization (`Named`, `Templated`).

## Request Boundary

Form requests handle transport sanitation and coercion, then construct the DTO.

```
public function toPitchDraft(): PitchDraft
{
    $sanitized = $this->validated();

    return new PitchDraft(
        speaker_name: trim((string) ($sanitized['speaker_name'] ?? '')),
        speaker_email: trim((string) ($sanitized['speaker_email'] ?? '')),
        talk_title: trim((string) ($sanitized['talk_title'] ?? '')),
        talk_duration_minutes: $this->normalizeDuration($sanitized['talk_duration_minutes'] ?? null),
        skill_level: trim((string) ($sanitized['skill_level'] ?? '')),
        highlights: array_values(array_filter(array_map('trim', $sanitized['highlights'] ?? []))),
    );
}

```

Request attributes remain focused on HTTP behavior, like `#[RedirectToRoute]`.

## Adapter to Laravel Exceptions

Respect\Validation exceptions are converted to Laravel `ValidationException` once, in a small adapter.

```
final class RespectAttributeValidator
{
    public function validate(object $dto): void
    {
        try {
            v::attributes()->assert($dto);
        } catch (RespectValidationException $exception) {
            $messages = $exception->getMessages();
            unset($messages['__root__']);

            throw ValidationException::withMessages($messages);
        }
    }
}

```

This preserves standard Laravel response behavior for both web and API flows. If your project has multiple DTO classes, you can use this same adapter for them all.

## Reusing One Payload Map

`PitchDraft::toAttributes()` is reused for both persistence and API output.
- persistence path: `Pitch::create($draft->toAttributes())`
- response path: `$pitch->toDraft()->toAttributes()`


Using one mapping function avoids duplicated field lists and keeps write/read payloads aligned.

## Operational Notes

The approach introduces one integration component (`RespectAttributeValidator`) and one DTO-to-model reconstruction method (`Pitch::toDraft()`). In exchange, the validation contract is explicit, centralized, and reusable across multiple entry points.

## Summary

This architecture keeps Laravel responsible for transport and persistence concerns, while domain validation remains defined in one DTO contract through Respect attributes. The result is lower duplication and a stricter single source of truth for validation logic.
