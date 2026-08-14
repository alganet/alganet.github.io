<!--
SPDX-FileCopyrightText: 2026 Alexandre Gomes Gaigalas <alganet@gmail.com>

SPDX-License-Identifier: CC-BY-NC-SA-4.0
-->
---
alt: 2026-02-22-23-Leveraging-Attributes-With-Respect-Validation-and-Laravel
date: 22 de Fevereiro de 2026
author: Alexandre Gomes Gaigalas
lang: pt
---

# Aproveitando Atributos com Respect\Validation e Laravel

O exemplo completo deste post está disponível no [GitHub](https://github.com/alganet/attributes-laravel-validation).

## Contexto

Lógica de validação muitas vezes acaba distribuída entre regras da request, verificações em controladores, helpers de modelos e serializadores. Desse jeito, as validações para o mesmo campo podem divergir com o tempo.

Este exemplo usa um único objeto de domínio como fonte de verdade para validações e mapeamento de payload, e em seguida integra esse objeto ao tratamento de requisições e persistência do Laravel.

## Objetivo de Projeto

O objetivo é manter uma definição central para:
- validações de domínio
- mensagens de validação
- mapeamento de campos de persistência/saída


`PitchDraft` é essa definição autoritativa.

## Contrato de Domínio

`PitchDraft` declara validações diretamente nos parâmetros tipados do construtor usando atributos do Respect.

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

Isso mantém a composição de regras explícita (`AllOf`, `ShortCircuit`, `Between`, `Each`) e localiza a customização de mensagens (`Named`, `Templated`).

## Borda das Requests

Requests de formulário lidam com sanitização e conversão, e então constroem o DTO.

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

Os atributos da request permanecem focados em comportamento HTTP, tal como `#[RedirectToRoute]`.

## Adaptador para Exceções do Laravel

Exceções do Respect\Validation são convertidas para ValidationException do Laravel uma vez, em um pequeno adaptador.

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

Isso preserva o comportamento padrão de resposta do Laravel para fluxos web e de API. Se seu projeto tiver várias classes DTO, você pode usar este mesmo adaptador para todas elas.

## Reutilizando Um Único Mapeamento de Payload

`PitchDraft::toAttributes()` é reutilizado tanto para persistência quanto para saída de API.
- caminho de persistência: `Pitch::create($draft->toAttributes())`
- caminho de resposta: `$pitch->toDraft()->toAttributes()`


Usar uma única função de mapeamento evita listas de campos duplicadas e mantém os payloads de escrita/leitura alinhados.

## Notas Operacionais

A abordagem introduz um componente de integração (`RespectAttributeValidator`) e um método de reconstrução de DTO para modelo (`Pitch::toDraft()`). Em troca, o contrato de validação fica explícito, centralizado e reutilizável em vários pontos de entrada.

## Resumo

Esta arquitetura mantém o Laravel responsável pelas preocupações de transporte e persistência, enquanto a validação de domínio permanece definida em um único contrato DTO por meio de atributos do Respect. O resultado é menos duplicação e uma fonte única de verdade mais rígida para a lógica de validação.
