# Papacaliente

Juego multijugador de **papa caliente en Roblox**. El objetivo es construir una experiencia de partidas rápidas con una arquitectura reproducible entre Roblox Studio y código fuente.

## Estado

El proyecto está en **construcción**. Existe una copia local con trabajo pendiente de publicar; este README debe reconciliarse con esa rama antes de fusionarse para no perder documentación ni cambios de juego.

## Alcance conocido

- Experiencia multijugador basada en rondas de papa caliente.
- Código compartido, lógica de servidor y controladores de cliente separados.
- Configuración local de Rojo para sincronizar el proyecto con Roblox Studio.
- Documentación local de QA, lanzamiento, economía y monetización pendiente de consolidar en GitHub.

## Stack

- Roblox Studio
- Luau
- Rojo
- Aftman para herramientas reproducibles

## Arquitectura prevista

- `ReplicatedStorage/Shared`: configuración y contratos compartidos.
- `ServerScriptService`: servicios y autoridad del servidor.
- `StarterPlayerScripts`: controladores y experiencia del cliente.

## Puesta en marcha

1. Instala las herramientas declaradas por el proyecto cuando la configuración local sea publicada.
2. Inicia el servidor de Rojo.
3. Conecta Roblox Studio al proyecto.
4. Ejecuta una partida de prueba antes de publicar cambios.

Nunca publiques secretos, identificadores privados ni archivos de entorno.

<!-- portfolio-os:project-context:start -->
## Estado y hoja de ruta

> Contexto de portafolio actualizado el 28 de julio de 2026.

- **Estado:** en construcción.
- **Clasificación provisional:** Gaming y creadores.
- **Rama principal:** `main`.
- **Objetivo inmediato:** reconciliar los cambios locales, validar el flujo jugable y preparar una beta privada.

### Próximos pasos

- [ ] Consolidar y publicar la estructura de Rojo sin perder cambios locales.
- [ ] Validar el bucle de ronda, transferencia de la papa y condiciones de victoria.
- [ ] Probar persistencia, economía, recompensas y monetización con datos controlados.
- [ ] Ejecutar la matriz de QA en servidor privado.
- [ ] Documentar métricas de retención, participación y estabilidad.
- [ ] Actualizar este README después de reconciliar la copia local.

### Criterio para avanzar

El proyecto avanza cuando una partida completa puede ejecutarse de forma reproducible, sin errores críticos y con una guía de beta verificable.
<!-- portfolio-os:project-context:end -->
