---
name: SportGroups App
description: Organización de grupos deportivos y comunitarios para Argentina
colors:
  sunset-coral: "#E2693F"
  coral-soft: "#FADBCC"
  coral-ink: "#95371F"
  dusk-plum: "#8868B8"
  plum-soft: "#ECE2F1"
  plum-ink: "#553F86"
  field-green: "#2DA67D"
  green-soft: "#D9F1E5"
  red-card: "#DA4A2C"
  red-soft: "#FCD9D0"
  kit-white: "#FFFFFF"
  chalk-surface: "#F1ECE7"
  canvas: "#F8F5F3"
  dugout: "#2A211E"
  dugout-muted: "#756864"
  line-light: "#E8E2DD"
  line-strong: "#D6CFC8"
  dark-pitch: "#1A1512"
  dark-bench: "#26201C"
typography:
  display:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontWeight: 700
    letterSpacing: "-0.8px"
    lineHeight: 1.1
  headline:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontWeight: 700
    letterSpacing: "-0.4px"
    lineHeight: 1.2
  title:
    fontFamily: "Bricolage Grotesque, system-ui, sans-serif"
    fontWeight: 700
    letterSpacing: "-0.2px"
    lineHeight: 1.3
  body:
    fontFamily: "DM Sans, system-ui, sans-serif"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "DM Sans, system-ui, sans-serif"
    fontWeight: 600
    letterSpacing: "0.1px"
    lineHeight: 1.2
rounded:
  pill: "999px"
  card: "20px"
  input: "16px"
  dialog: "24px"
  sheet: "28px"
  icon-tile: "12px"
  snack: "14px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.sunset-coral}"
    textColor: "{colors.kit-white}"
    rounded: "{rounded.pill}"
    padding: "0 20px"
    height: "48px"
    typography: "{typography.label}"
  button-primary-hover:
    backgroundColor: "{colors.coral-ink}"
    textColor: "{colors.kit-white}"
    rounded: "{rounded.pill}"
  button-soft:
    backgroundColor: "{colors.coral-soft}"
    textColor: "{colors.coral-ink}"
    rounded: "{rounded.pill}"
    padding: "0 20px"
    height: "48px"
  button-outline:
    backgroundColor: "{colors.kit-white}"
    textColor: "{colors.dugout}"
    rounded: "{rounded.pill}"
    padding: "0 20px"
    height: "48px"
  button-danger:
    backgroundColor: "{colors.red-card}"
    textColor: "{colors.kit-white}"
    rounded: "{rounded.pill}"
    padding: "0 20px"
    height: "48px"
  chip-neutral:
    backgroundColor: "{colors.chalk-surface}"
    textColor: "{colors.dugout}"
    rounded: "{rounded.pill}"
    padding: "4px 10px"
  chip-primary:
    backgroundColor: "{colors.coral-soft}"
    textColor: "{colors.coral-ink}"
    rounded: "{rounded.pill}"
    padding: "4px 10px"
  chip-good:
    backgroundColor: "{colors.green-soft}"
    textColor: "{colors.field-green}"
    rounded: "{rounded.pill}"
    padding: "4px 10px"
  chip-danger:
    backgroundColor: "{colors.red-soft}"
    textColor: "{colors.red-card}"
    rounded: "{rounded.pill}"
    padding: "4px 10px"
  card-default:
    backgroundColor: "{colors.kit-white}"
    rounded: "{rounded.card}"
    padding: "16px"
---

# Design System: SportGroups App

## 1. Overview

**Creative North Star: "La Cancha y la Caja"**

Dos mundos en una misma app: la cancha, donde la energía es colectiva, directa y sin vueltas; y la caja, donde la confianza se gana con claridad y orden. El sistema visual no elige entre los dos: los sostiene en tensión productiva. El coral del atardecer de un partido es el mismo color que el botón de "Confirmar pago". La pluma de ciruela que marca un evento en el calendario también separa un gasto registrado. No hay modo deportivo y modo administrativo: hay un solo producto que hace ambas cosas con la misma voz.

La filosofía visual es la del uniforme del equipo: reconocible, funcional, propio. No es el kit de una marca de ropa deportiva global, ni la ropa de trabajo de una empresa. Es la camiseta que compraron juntos en 2019 y que todos saben reconocer. Identidad colectiva construida en lo simple.

El sistema rechaza explícitamente la frialdad corporativa de Monday o Asana, el atletismo de élite de Strava o Nike, y la genericidad del SaaS neutro. Si parece que podría ser cualquier app de gestión, fracasó.

**Key Characteristics:**
- Paleta cálida con identidad propia: coral como acción principal, ciruela como acento secundario
- Tipografía con carácter: Bricolage Grotesque en títulos (tensa, deportiva), DM Sans en cuerpo (directa, legible)
- Bordes redondeados generosos: nada es rígido ni esquinado
- Flat-by-default: cero sombras decorativas, profundidad a través de superficie y borde
- Modo claro con modo oscuro cálido incluido (no frío ni azulado)

## 2. Colors: La Paleta Atardecer

El sistema tiene tres familias de color: acción (coral), acento (ciruela), y semántica (verde/rojo). Los neutros son cálidos, nunca grises neutros.

### Primary

- **Sunset Coral** (`#E2693F`): El color de acción principal. Botones primarios, indicadores activos, tabulación seleccionada, FAB. Aparece como el "hacer algo" de la app. No usar decorativamente.
- **Coral Soft** (`#FADBCC`): Fondo de estado seleccionado, chips primarios, fondos de confirmación. La versión "ya lo hice" del coral.
- **Coral Ink** (`#95371F`): Texto sobre fondos coral soft, colores de texto de énfasis primario. Nunca de fondo.

### Secondary

- **Dusk Plum** (`#8868B8`): Acento de calendario, eventos especiales, segunda acción cuando el coral ya está en uso. Complementa el coral sin competir.
- **Plum Soft** (`#ECE2F1`): Fondos de chips de evento/agenda.
- **Plum Ink** (`#553F86`): Texto sobre fondos plum soft.

### Neutral (Semantic)

- **Field Green** (`#2DA67D`): Estados de éxito, pagos aprobados, tareas completadas. El verde del campo que significa "todo bien".
- **Green Soft** (`#D9F1E5`): Fondo de estado success.
- **Red Card** (`#DA4A2C`): Error, pago rechazado, acción destructiva. La tarjeta roja.
- **Red Soft** (`#FCD9D0`): Fondo de estado error/danger.

### Neutral (Surface)

- **Kit White** (`#FFFFFF`): Superficie de cards y componentes. El blanco del formulario, no del fondo.
- **Chalk Surface** (`#F1ECE7`): Superficie alternativa (chips neutros, backgrounds de inputs sin foco, hover states).
- **Canvas** (`#F8F5F3`): Background general de la app. Tibio, no cream saturado.
- **Dugout** (`#2A211E`): Color de texto principal. Café oscuro, no negro puro.
- **Dugout Muted** (`#756864`): Texto secundario, placeholders, labels inactivos.
- **Line Light** (`#E8E2DD`): Borde default de cards, inputs, divisores.
- **Line Strong** (`#D6CFC8`): Borde focused, divisores más marcados.

### Dark Mode

- **Dark Pitch** (`#1A1512`): Background oscuro. Marrón muy profundo, no negro.
- **Dark Bench** (`#26201C`): Surface oscuro. Un paso más claro que el pitch.

### Named Rules

**La Regla del Coral Único.** El coral solo aparece en elementos de acción (botón primario, estado activo, FAB). Nunca como color decorativo o de fondo de sección. Su escasez es lo que le da peso.

**La Regla del Neutro Cálido.** Todos los grises tienen temperatura positiva. Nunca usar `Colors.grey` del sistema, `#808080`, ni cualquier neutro sin tonalidad. El neutro más frío de la paleta es `#756864`, que todavía tiene hue marrón/naranja.

## 3. Typography

**Display Font:** Bricolage Grotesque (variable, Google Fonts)
**Body Font:** DM Sans (variable, Google Fonts)

**Character:** Bricolage Grotesque lleva la energía: compacto, con personalidad pero sin ser decorativo. DM Sans es el par de trabajo: legible a tamaño pequeño, cómodo en bloques de texto, versátil en pesos. El par funciona porque contrasta en sabor (grotesco variable vs humanista) sin competir en registro.

### Hierarchy

- **Display** (Bricolage Grotesque, 700, ~57sp, LS -0.8px): Solo pantallas de onboarding o hero. No aparece en el flujo normal de la app.
- **Headline** (Bricolage Grotesque, 700, 24-32sp, LS -0.4px): Títulos de sección principal, nombre de grupo en header de GrupoPage, headings de cards destacadas.
- **Title** (Bricolage Grotesque, 700, 16-22sp, LS -0.2px): Títulos de pantalla (AppBar), nombres de items en listas, headings de bottom sheets.
- **Body** (DM Sans, 400, 14-16sp, LH 1.5): Texto de noticias, descripciones, contenido de comentarios. Máximo 65-75ch en desktop.
- **Label** (DM Sans, 600, 11-14sp, LS 0.1-0.5): Botones, chips, tabs, labels de form field, badges. El peso 600 da presencia sin necesitar tamaño grande.

### Named Rules

**La Regla del Título.** Bricolage Grotesque es solo para títulos y displays: AppBar, card headers, screen titles, section headings. Nunca en botones, labels de form, chips, o tablas. La mezcla de display font en UI controls rompe la jerarquía.

## 4. Elevation

El sistema es flat-by-default. Las superficies se distinguen por color de fondo y borde, no por sombra. Una card sobre el canvas no proyecta sombra; su borde `1px #E8E2DD` la separa del fondo.

La única excepción son el FAB (elevation 4, sombra de material) y el AppBar cuando hay scroll (`scrolledUnderElevation: 0.5`), que refuerzan jerarquía estructural, no decorativa.

### Shadow Vocabulary

- **FAB shadow** (`elevation: 4, Material 3`): Solo el botón flotante de acción principal. Señala "siempre disponible".
- **Scrolled AppBar** (`elevation: 0.5`): Aparece al scrollear para separar el header del contenido.

### Named Rules

**La Regla del Borde.** La profundidad se expresa con borde, no con sombra. Un card en superficie blanca sobre fondo canvas ya tiene contraste suficiente; el borde `1px Line Light` confirma el contenedor sin agregar peso visual. Si querés agregar jerarquía, cambiar el fondo de surface a chalk-surface, no agregar sombra.

## 5. Components

### Buttons

Los botones son siempre píldoras (radius 999px). No existe botón rectangular.

- **Shape:** Fully rounded (999px radius). Altura mínima 52px (touch target garantizado).
- **Primary:** Fondo Sunset Coral, texto blanco, DM Sans 600 15sp. Full-width por default (double.infinity).
- **Soft:** Fondo Coral Soft, texto Coral Ink. Para acciones secundarias en la misma pantalla que una primaria.
- **Outline:** Fondo blanco, borde Line Light, texto Dugout. Acciones de menor peso o cancelar.
- **Ghost:** Fondo transparente, texto Dugout. Solo en contextos donde el outline también sería demasiado.
- **Danger:** Fondo Red Card, texto blanco. Solo para acciones destructivas confirmadas.
- **Accent:** Fondo Dusk Plum, texto blanco. Para acciones de agenda/calendario.
- **States:** Al presionar, opacidad reduce ligeramente (ink de Material). No hay cambio de forma ni animación de layout.
- **SGPillButton sizes:** sm (36px altura), md (48px), lg (56px).

### Chips (SGChip)

- **Style:** Fondo tintado + texto ink de mismo tono, 11px DM Sans 600, padding `4px 10px`, radius 999px.
- **Tones:** neutral (chalk surface), primary (coral), accent (plum), good (green), danger (red).
- **Filled variant:** Usa el fg como background con texto blanco. Para estados activos/seleccionados.
- **SGEyebrow:** Labels de sección en uppercase, 11px, LS 1.2, `Dugout Muted`. Siempre con línea divisora a la derecha.

### Cards (SGCard)

- **Corner Style:** Generosamente redondeado (20px radius)
- **Background:** Kit White sobre canvas general
- **Shadow Strategy:** Ninguna. Solo borde 1px Line Light.
- **Border:** `1px solid #E8E2DD` siempre presente.
- **Internal Padding:** 16px por default.
- **Variante con color:** Se puede pasar `color` para fondos semánticos (goodSoft, dangerSoft, primarySoft).
- **Sin nested cards.** Un SGCard nunca contiene otro SGCard.

### Inputs / Fields

- **Style:** Fondo Kit White, borde 1px Line Light, radius 16px. Filled=true (no underline).
- **Focus:** Borde 2px Sunset Coral. Sin glow ni shadow extra.
- **Error:** Borde 2px Red Card, helper text en Red Card.
- **Disabled:** Opacidad reducida, cursor not-allowed.
- **Padding interno:** 16px horizontal y vertical.

### Navigation

**Mobile:** Bottom navigation bar con 5 tabs. Íconos 24px + label 12px DM Sans 600. Tab activa: fondo Coral Soft con ícono Coral, radio 999px (pill indicator). Altura fija 60px + safe area.

**Desktop (≥900px):** Sidebar 260px con logo/brand en top, nav items con íconos, lista de grupos del usuario, user card en bottom. Fondo Canvas. Topbar 64px con título dinámico, search pill, notificaciones, ayuda.

**Tabs (GrupoPage):** TabBar con indicador underline Coral, labels DM Sans 700 12sp (activo) / 500 (inactivo), solo visible en mobile.

### SGAvatar

- **Initials mode:** Círculo con fondo Primary coral, inicial en Bricolage Grotesque 700 blanco.
- **Image mode:** `CircleAvatar` con `NetworkImage`. (Pendiente migración a `CachedNetworkImage`.)
- **Size variants:** 32px, 40px, 48px, 56px son los más comunes.

### SGIconTile

- Cuadrado 40px default, radius 12px, fondo de color tintado + ícono centrado (50% del tile).
- Usado para íconos de funcionalidad (cuotas, gastos, campañas) en el hub del grupo.

### Dialogs / Bottom Sheets

- **Dialog:** radius 24px, fondo Kit White (light) / Dark Bench (dark). Sin shadow en el overlay.
- **Bottom Sheet:** radius 28px top, drag handle 40×4px en Line Strong, fondo Kit White.
- **Sin modales innecesarios.** Primero inline, luego bottom sheet, modal solo para confirmaciones destructivas.

## 6. Do's and Don'ts

### Do:
- **Do** usar `AppTheme.good` (`#2DA67D`) y `AppTheme.danger` (`#DA4A2C`) para todos los estados semánticos de éxito y error. Nunca valores hex directos como `0xFF1F7A5A` o `0xFF8C2A14`.
- **Do** usar `AppTheme.roleColor(RolMiembro)` para colorear roles (cuando esté implementado). Actualmente los roles no tienen constantes de tema — agregar antes de expandir el sistema.
- **Do** usar `SGCard` para todos los contenedores de card. No crear `Container` custom con `BoxDecoration` + radius + border cuando ya existe el componente.
- **Do** usar `SGAvatar` para todos los avatares de usuario y grupo.
- **Do** usar `SGChip` para todos los badges de estado (pago, tarea, rol). Las tones son el vocabulario semántico.
- **Do** construir con `SGPillButton` para acciones secundarias y terciarias; `FilledButton` o `ElevatedButton` del tema para las primarias full-width.
- **Do** mantener touch targets mínimo 48×48px en mobile. Toda acción interactiva.
- **Do** mostrar skeleton states en listas async, no spinners centrados.
- **Do** usar `CachedNetworkImage` / `CachedNetworkImageProvider` para todas las imágenes de red.

### Don't:
- **Don't** usar `Colors.grey`, `Colors.blue`, `Colors.red`, ni ningún color del sistema Material fuera de los widgets de theme. Toda la paleta está en `AppTheme`.
- **Don't** usar `Color(0xFF...)` hardcodeado en archivos de presentation. Centralizar en `AppTheme`.
- **Don't** crear botones rectangulares (radius 0 o < 8px). El sistema solo tiene píldoras.
- **Don't** usar Bricolage Grotesque en labels de botones, chips, tabs, o texto de form field. Solo títulos y headlines.
- **Don't** agregar sombras decorativas a cards o panels. La jerarquía viene del borde y el color de superficie.
- **Don't** hacer que la app parezca una app de gestión empresarial (Monday/Asana): sin tablas densas sin jerarquía, sin header azul corporativo, sin typography system plana.
- **Don't** hacer que parezca una app deportiva de élite (Strava/Nike): sin hero images de atletas, sin gradientes de alta saturación, sin uppercase agresivo.
- **Don't** usar SaaS genérico: sin glassmorphism, sin hero metrics con números grandes y gradiente, sin cream backgrounds saturado de AI.
- **Don't** usar `Image.network()`. Siempre `CachedNetworkImage`.
- **Don't** hacer `Colors.black.withValues(alpha: x)` o `Colors.white.withValues(alpha: x)` para overlays. Usar los tokens de color oscuro/claro del tema o agregar un helper `AppTheme.overlay()`.
- **Don't** esconder las tabs de GrupoPage en desktop sin sustituirlas por navegación lateral equivalente.
