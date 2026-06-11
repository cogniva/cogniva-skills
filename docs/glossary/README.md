# Glossary

One agreed meaning per domain term. Reference these in every discussion; propose new entries as terms emerge.

## Module

A vertical slice of a system under `src/Modules/<Name>/`, containing its own Clean Architecture layers: [Contracts](#contracts), [Domain](#domain), [Application](#application), [Infrastructure](#infrastructure), optional [Client](#client), and [Module UI](#module-ui). Modules communicate with each other **only** through Contracts.
_Avoid_: feature, component, slice, bounded context

```mermaid
graph TD
  UI["Module UI (Blazor RCL)"] --> C[Contracts]
  Client["Client (HTTP impl, optional)"] --> C
  App[Application] -->|implements| C
  App --> D[Domain]
  Infra[Infrastructure] --> App
  Infra --> D
  Host([Host]) -. registers App or Client .-> C
```

## Contracts

A [Module](#module)'s pure public surface: interfaces, DTOs, and integration events. The only project other Modules and UIs may reference; it references nothing.
_Avoid_: public API, client interface

## Domain

A [Module](#module)'s entities, value objects, and domain logic. References nothing.

## Application

A [Module](#module)'s use-case layer and the **in-process** implementation of its [Contracts](#contracts). References Domain and Contracts.
_Avoid_: services layer, business logic layer

## Infrastructure

Persistence and external-service implementations for a [Module](#module). References Application and Domain.

## Client

An optional **HTTP** implementation of a [Module](#module)'s [Contracts](#contracts), used when the Module is deployed remotely. A [Host](#host) registers it in place of [Application](#application); consumers never know which is running.
_Avoid_: proxy, API wrapper, SDK

## Module UI

A Blazor Razor class library presenting a [Module](#module)'s functionality. Depends only on [Contracts](#contracts), so the same UI runs in any [Host](#host) — web or WPF.
_Avoid_: front-end, component library

## Host

A composition root — a web app, or a WPF app with BlazorWebView — that assembles [Modules](#module) and registers either [Application](#application) (in-process) or [Client](#client) (HTTP) against each Module's [Contracts](#contracts).
_Avoid_: app shell, launcher

## Vertical Slice

The architectural style of dividing a system by business capability rather than technical layer. Here, each slice is a [Module](#module).

## Cogniva

The brand name for this team's shared development tooling. The Claude Code plugin marketplace in this repo is named `cogniva` (hosted at github.com/cogniva/cogniva-skills); tools ship as plugins under it: `cogniva-skills` (shared skills: glossary, auto-doc) and `repo-foundry` (repo scaffolding toolkit). Tools are never named after individual team members.

## Plan

An implementation plan document in `docs/plans/`, produced by the writing-plans workflow. Automatically gets an HTML twin via the plan-to-html hook.

## Spec

A validated design document in `docs/superpowers/specs/`, produced by the brainstorming workflow. Also gets an HTML twin automatically.
