<!--
SPDX-FileCopyrightText: Copyright (c) 2024-2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
SPDX-License-Identifier: Apache-2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

![Banner de Dynamo](./docs/assets/img/dynamo-frontpage-banner.png)

[![Licencia](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Versión de GitHub](https://img.shields.io/github/v/release/ai-dynamo/dynamo)](https://github.com/ai-dynamo/dynamo/releases/latest)
[![PyPI](https://img.shields.io/pypi/v/ai-dynamo)](https://pypi.org/project/ai-dynamo/)
[![Preguntar a DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/ai-dynamo/dynamo)
[![Discord](https://dcbadge.limes.pink/api/server/D92uqZRjCZ?style=flat)](https://discord.gg/D92uqZRjCZ)
![Colaboradores de la comunidad](https://img.shields.io/badge/community_contributors-70%2B-brightgreen)

| **[Documentación](https://docs.nvidia.com/dynamo/)** | **[Hoja de ruta](https://github.com/ai-dynamo/dynamo/issues/5506)** | **[Recetas](https://github.com/ai-dynamo/dynamo/tree/main/recipes)** | **[Ejemplos](https://github.com/ai-dynamo/dynamo/tree/main/examples)** | **[Contenedores precompilados](https://catalog.ngc.nvidia.com/orgs/nvidia/teams/ai-dynamo/collections/ai-dynamo)** | **[Resumen](docs/digest/index.mdx)** | **[Propuestas de diseño](https://github.com/ai-dynamo/enhancements)** | **[Cómo contribuir](#comunidad-y-contribuciones)** |

<!-- La insignia SVG usa systemLanguage, por lo que solo se muestra para preferencias de idioma de navegador en chino simplificado/China. -->
<p align="left">
  <a href="./README.zh-CN.md" hreflang="zh-CN"><img src="./docs/assets/img/readme-zh-cn-link.svg" alt="简体中文" height="28" /></a>
</p>

# Dynamo

<!-- BANNER TEMPORAL: eliminar cuando las recetas de Nemotron Ultra 3 maduren. -->
> [!NOTE]
> **Recetas Day-0 de Nemotron 3 Ultra disponibles.** Las rutas de despliegue en Kubernetes para [Nemotron 3 Ultra](recipes/nemotron-3-ultra/) probadas y optimizadas para rendimiento se han incorporado a main para **vLLM**, con una imagen de contenedor precompilada publicada en NGC.\
> Las recetas incluyen enrutamiento consciente de KV, predicción de múltiples tokens (MTP) y prefill/decode desagregados

**La pila de inferencia de código abierto a escala de centro de datos.** Dynamo es la capa de orquestación por encima de los motores de inferencia: no reemplaza a SGLang, TensorRT-LLM ni vLLM; los convierte en un sistema de inferencia coordinado de múltiples nodos. El servicio desagregado, el enrutamiento inteligente, el almacenamiento en caché KV de varios niveles y el escalado automático trabajan juntos para maximizar el rendimiento y minimizar la latencia en cargas de trabajo de LLM, razonamiento, multimodales y generación de video.

Construido en Rust para rendimiento y en Python para extensibilidad.

## Cuándo usar Dynamo

- Sirves LLMs en **múltiples GPUs o nodos** y necesitas coordinarlos
- Quieres **enrutamiento consciente de KV** para evitar cálculos de prefill redundantes
- Necesitas **escalar prefill y decode de forma independiente** (servicio desagregado)
- Quieres **escalado automático** que cumpla SLAs de latencia con el costo total de propiedad (TCO) mínimo
- Necesitas **arranques en frío rápidos** al levantar nuevas réplicas

Si ejecutas un único modelo en una única GPU, probablemente tu motor de inferencia por sí solo sea suficiente.

**Resumen del soporte de características:**

| | [SGLang](https://docs.nvidia.com/dynamo/backends/sg-lang) | [TensorRT-LLM](https://docs.nvidia.com/dynamo/backends/tensor-rt-llm) | [vLLM](https://docs.nvidia.com/dynamo/backends/v-llm) |
|---|:----:|:----------:|:--:|
| [**Servicio desagregado**](https://docs.nvidia.com/dynamo/design-docs/disaggregated-serving) | ✅ | ✅ | ✅ |
| [**Enrutamiento consciente de KV**](https://docs.nvidia.com/dynamo/components/router) | ✅ | ✅ | ✅ |
| [**Planner basado en SLA**](https://docs.nvidia.com/dynamo/components/planner/planner-guide) | ✅ | ✅ | ✅ |
| [**KVBM**](https://docs.nvidia.com/dynamo/components/kvbm) | 🚧 | ✅ | ✅ |
| [**Multimodal**](https://docs.nvidia.com/dynamo/user-guides/multimodal) | ✅ | ✅ | ✅ |
| [**Llamada a herramientas**](docs/tool-calling/README.md) | ✅ | ✅ | ✅ |

> **[Matriz completa de características →](https://docs.nvidia.com/dynamo/resources/feature-matrix)** — LoRA, migración de solicitudes, decodificación especulativa e interacciones entre características.

## Resultados clave

| Resultado | Contexto |
|--------|---------|
| Rendimiento por GPU **7x** mayor | DeepSeek R1 en GB200 NVL72 con Dynamo frente a B200 sin Dynamo ([InferenceX](https://inferencex.semianalysis.com/)) |
| Inicio de modelo **7x** más rápido | Transmisión de pesos ModelExpress (DeepSeek-V3 en H200) |
| Tiempo hasta el primer token **2x** más rápido | Enrutamiento consciente de KV, Qwen3-Coder 480B ([benchmark de Baseten](https://www.baseten.co/blog/how-baseten-achieved-2x-faster-inference-with-nvidia-dynamo/)) |
| **80%** menos incumplimientos de SLA | Autoescalado de Planner con TCO 5% menor ([Alibaba APSARA 2025 @ 2:50:00](https://yunqi.aliyun.com/2025/session?agendaId=6062)) |
| Rendimiento **750x** mayor | DeepSeek-R1 en GB300 NVL72 ([InferenceXv2](https://inferencex.semianalysis.com/)) |


## Qué hace Dynamo

La mayoría de los motores de inferencia optimizan una única GPU o un único nodo. Dynamo es la **capa de orquestación por encima de ellos**: convierte un clúster de GPUs en un sistema de inferencia coordinado.

<p align="center">
  <img src="./docs/assets/img/dynamo-readme-overview.svg" alt="Resumen de la arquitectura de Dynamo" width="600" />
</p>

**[Análisis profundo de la arquitectura →](https://docs.nvidia.com/dynamo/design-docs/overall-architecture)**

### Capacidades principales

| Capacidad | Qué hace | Por qué importa |
|------------|-------------|----------------|
| [**Prefill/Decode desagregados**](https://docs.nvidia.com/dynamo/design-docs/disaggregated-serving) | Separa prefill y decode en pools de GPU escalables de forma independiente | Maximiza la utilización de GPU; cada fase se ejecuta en hardware ajustado para su carga de trabajo |
| [**Enrutamiento consciente de KV**](https://docs.nvidia.com/dynamo/components/router) | Enruta solicitudes según la carga del worker y la superposición de caché KV | Elimina cálculos de prefill redundantes: TTFT 2x más rápido |
| [**KV Block Manager (KVBM)**](https://docs.nvidia.com/dynamo/components/kvbm) | Descarga la caché KV a través de GPU → CPU → SSD → almacenamiento remoto | Extiende la longitud de contexto efectiva más allá de la memoria de la GPU |
| [**ModelExpress**](https://github.com/ai-dynamo/modelexpress) | Transmite pesos del modelo de GPU a GPU mediante NIXL/NVLink | Arranque en frío 7x más rápido para nuevas réplicas |
| [**Planner**](https://docs.nvidia.com/dynamo/components/planner/planner-guide) | Autoescalador impulsado por SLA que perfila cargas de trabajo y dimensiona pools correctamente | Cumple objetivos de latencia con el costo total de propiedad (TCO) mínimo |
| [**Grove**](https://github.com/ai-dynamo/grove) | Operador de K8s para planificación grupal consciente de la topología (NVL72) | Ubica cargas de trabajo de forma óptima entre racks, hosts y nodos NUMA |
| [**AIConfigurator**](https://github.com/ai-dynamo/aiconfigurator) | Simula más de 10K configuraciones de despliegue en segundos | Encuentra la configuración de servicio óptima sin gastar horas de GPU |
| [**Tolerancia a fallos**](https://docs.nvidia.com/dynamo/user-guides/fault-tolerance/request-migration) | Comprobaciones de salud canary + migración de solicitudes en curso | Los workers fallan; las solicitudes de los usuarios no |

### Nuevo en 1.0

- **Despliegue sin configuración ([DGDR](https://docs.nvidia.com/dynamo/kubernetes-deployment/deploy-models/dgdr-reference))** *(beta):* Especifica modelo, HW y SLA en un YAML: AIConfigurator perfila automáticamente la carga de trabajo, Planner optimiza la topología y Dynamo despliega
- **Inferencia agéntica:** Indicaciones por solicitud para prioridad de latencia, longitud de salida esperada y TTL de fijación de caché. Integraciones con [LangChain](https://docs.langchain.com/oss/python/integrations/chat/nvidia_ai_endpoints#use-with-nvidia-dynamo) + [NeMo Agent Toolkit](https://github.com/NVIDIA/NeMo-Agent-Toolkit)
- **E/P/D multimodal:** Encode/prefill/decode desagregados con caché de embeddings: TTFT 30% más rápido en cargas de trabajo de imágenes
- **Generación de video:** Soporte nativo de [FastVideo](https://github.com/hao-ai-lab/FastVideo) + [SGLang Diffusion](https://lmsys.org/blog/2026-02-16-sglang-diffusion-advanced-optimizations/): 1080p en tiempo real en una sola B200
- **Plugin K8s Inference Gateway:** Enrutamiento consciente de KV dentro del gateway estándar de Kubernetes
- **Descarga de KV a nivel de almacenamiento:** Soporte de blobs S3/Azure + eventos KV globales para visibilidad de caché en todo el clúster

## Modos de despliegue

Dynamo puede ejecutarse en dos modos de despliegue. Ambos exponen una API compatible con OpenAI y admiten los mismos backends, servicio desagregado y enrutamiento consciente de KV.

| Modo | Qué es | Cuándo usarlo |
|------|------------|-------------|
| **Standalone** *(predeterminado)* | El propio Frontend de Dynamo sirve HTTP y el Dynamo Router integrado toma decisiones de enrutamiento conscientes de KV. No se requiere gateway externo. | Desarrollo local, despliegues de un solo clúster y cualquier entorno donde quieras que Dynamo controle el punto de entrada de solicitudes de extremo a extremo. |
| **Gateway (GAIE)** | Dynamo se ejecuta detrás de un gateway de Kubernetes [Gateway API Inference Extension](https://gateway-api-inference-extension.sigs.k8s.io/). El enrutamiento consciente de KV se realiza en la capa de gateway mediante el Dynamo Endpoint Picker Plugin (EPP); el Frontend se ejecuta como sidecar en `--router-mode direct` y respeta la selección de worker por solicitud del EPP. | Plataformas Kubernetes de producción que ya estandarizan en Inference Gateway, clústeres multiinquilino o cuando necesitas políticas a nivel de gateway (autenticación, limitación de tasa, observabilidad) coubicadas con el enrutamiento consciente de KV. |

En modo **standalone**, el flujo de solicitudes es `client → Frontend → Router → workers`. En modo **gateway**, el flujo de solicitudes es `client → Inference Gateway → EPP (KV-aware routing) → Frontend sidecar (direct) → workers`.

Consulta la [guía de Inference Gateway (GAIE)](docs/kubernetes/inference-gateway.md) para ver la configuración completa, las características admitidas y la configuración del modo gateway.

## Inicio rápido

### Opción A: Contenedor (la más rápida)

```bash
# Extrae un contenedor precompilado (ejemplo de SGLang)
docker run --gpus all --network host --rm -it nvcr.io/nvidia/ai-dynamo/sglang-runtime:1.2.0

# Dentro del contenedor: inicia frontend y worker
python3 -m dynamo.frontend --http-port 8000 --discovery-backend file > /dev/null 2>&1 &
python3 -m dynamo.sglang --model-path Qwen/Qwen3-0.6B --discovery-backend file &

# Envía una solicitud
curl -s localhost:8000/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model": "Qwen/Qwen3-0.6B",
  "messages": [{"role": "user", "content": "¡Hola!"}],
  "max_tokens": 100
}' | jq
```

También disponibles: [`tensorrtllm-runtime:1.2.0`](https://docs.nvidia.com/dynamo/resources/release-artifacts) y [`vllm-runtime:1.2.0`](https://docs.nvidia.com/dynamo/resources/release-artifacts).

### Opción B: Instalar desde PyPI

Instala [uv](https://github.com/astral-sh/uv) (`curl -LsSf https://astral.sh/uv/install.sh | sh`) y luego:

```bash
uv pip install --prerelease=allow "ai-dynamo[sglang]"   # o [vllm]
```

> **Nota:** TensorRT-LLM requiere `pip` con `--extra-index-url https://pypi.nvidia.com`. Consulta la [guía de instalación](docs/getting-started/local-installation.md) para instrucciones específicas de TRT-LLM.

Luego inicia el frontend y un worker como se muestra arriba. Consulta la [guía de instalación completa](docs/getting-started/local-installation.md) para dependencias del sistema y notas específicas de backend.

### Opción C: Kubernetes (recomendada)

Para clústeres de producción de múltiples nodos, instala la [Dynamo Platform](https://docs.nvidia.com/dynamo/kubernetes-deployment/start-here/installation-guide) y despliega con un único manifiesto:

```yaml
# Despliegue sin configuración: especifica modelo + SLA, Dynamo se encarga del resto
apiVersion: nvidia.com/v1beta1
kind: DynamoGraphDeploymentRequest
metadata:
  name: my-model
spec:
  model: Qwen/Qwen3-0.6B
  backend: vllm
  sla:
    ttft: 200.0   # ms
    itl: 20.0     # ms
  autoApply: true
```

Recetas precompiladas para modelos comunes:

| Modelo | Framework | Modo | Receta |
|-------|-----------|------|--------|
| Llama-3-70B | vLLM | Agregado | [Ver](recipes/llama-3-70b/vllm/) |
| DeepSeek-R1 | SGLang | Desagregado | [Ver](recipes/deepseek-r1/sglang/) |
| Qwen3-32B-FP8 | TensorRT-LLM | Agregado | [Ver](recipes/qwen3-32b-fp8/trtllm/) |

Consulta [recipes/](recipes/README.md) para ver la lista completa. Guías específicas de nube: [AWS EKS](docs/kubernetes/cloud-providers/eks/eks.md) · [Google GKE](docs/kubernetes/cloud-providers/gke/gke.md) · [Azure AKS](docs/kubernetes/cloud-providers/aks/aks.md) · [Amazon ECS](docs/kubernetes/cloud-providers/ecs/ecs.md)

## Compilar desde el código fuente

Para colaboradores que quieren compilar y desarrollar localmente. Consulta la [guía de compilación completa](docs/getting-started/building-from-source.md) para más detalles.

```bash
# Instala dependencias del sistema (Ubuntu 24.04)
sudo apt install -y build-essential libhwloc-dev libudev-dev pkg-config libclang-dev protobuf-compiler python3-dev cmake

# Instala Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh && source $HOME/.cargo/env

# Crea un venv y compila
uv venv dynamo && source dynamo/bin/activate
uv pip install pip maturin
cd lib/bindings/python && maturin develop --uv && cd $PROJECT_ROOT
uv pip install -e lib/gpu_memory_service
uv pip install -e .
```

> Usuarios de VSCode/Cursor: consulta [`.devcontainer`](.devcontainer/README.md) para un entorno de desarrollo preconfigurado.

## Comunidad y contribuciones

Dynamo se construye de forma abierta con un modelo de desarrollo OSS-first. Damos la bienvenida a contribuciones de todo tipo.

- **[Guía de contribución](https://docs.nvidia.com/dynamo/getting-started/contribution-guide)** — Cómo contribuir código, documentación y recetas
- **[Propuestas de diseño](https://github.com/ai-dynamo/enhancements)** — RFCs para características importantes
- **[Office Hours](https://www.youtube.com/playlist?list=PL5B692fm6--tgryKu94h2Zb7jTFM3Go4X)** — Reuniones quincenales
- **[Reuniones de la comunidad](https://docs.google.com/document/d/1uR8xD_hlYGwV6QspvSc36k1H-wo1BUcVmFbHH9xlXd8/view)** – Reuniones semanales de la comunidad de desarrollo (miércoles 10:30 AM PT)
- **[Discord](https://discord.gg/D92uqZRjCZ)** — Chatea con el equipo y la comunidad
- **[Grabaciones de Dynamo Day](https://nvevents.nvidia.com/dynamoday)** — Análisis profundos de usuarios en producción

## Noticias recientes

- [03/15] [Dynamo 1.0 ya está aquí: listo para producción y con fuerte adopción de la comunidad](https://developer.nvidia.com/blog/introducing-nvidia-dynamo-a-low-latency-distributed-inference-framework-for-scaling-reasoning-ai-models/)
- [03/15] [NVIDIA Blackwell Ultra establece nuevos récords de inferencia en MLPerf](https://developer.nvidia.com/blog/nvidia-blackwell-ultra-sets-new-inference-records-in-mlperf-debut/)
- [03/15] [NVIDIA Blackwell lidera los benchmarks InferenceMax de SemiAnalysis](https://developer.nvidia.com/blog/nvidia-blackwell-leads-on-new-semianalysis-inferencemax-benchmarks/)
- [12/05] [Kimi K2 de Moonshot AI logra una aceleración de inferencia 10x con Dynamo en GB200](https://quantumzeitgeist.com/kimi-k2-nvidia-ai-ai-breakthrough/)
- [12/02] [Mistral AI ejecuta Mistral Large 3 con inferencia 10x más rápida usando Dynamo](https://www.marktechpost.com/2025/12/02/nvidia-and-mistral-ai-bring-10x-faster-inference-for-the-mistral-3-family-on-gb200-nvl72-gpu-systems/)
- [11/20] [Dell integra PowerScale con NIXL para un TTFT 19x más rápido](https://www.dell.com/en-us/dt/corporate/newsroom/announcements/detailpage.press-releases~usa~2025~11~dell-technologies-and-nvidia-advance-enterprise-ai-innovation.htm)

<details>
<summary>Noticias anteriores</summary>

Dynamo proporciona herramientas completas de benchmarking:

- **[Guía de benchmarking](docs/benchmarks/benchmarking.md)** – Compara topologías de despliegue usando AIPerf
- **[Despliegues impulsados por SLA](docs/components/planner/planner-guide.md)** – Optimiza despliegues para cumplir requisitos de SLA

## Especificación OpenAPI del frontend

El frontend compatible con OpenAI expone una especificación OpenAPI 3 en `/openapi.json`. Para generarla sin ejecutar el servidor:

```bash
cargo run -p dynamo-llm --bin generate-frontend-openapi
```

Esto escribe en `docs/reference/api/openapi.json`.

## Descubrimiento de servicios y mensajería

Dynamo usa TCP para la comunicación entre componentes. En Kubernetes, los recursos nativos ([CRDs + EndpointSlices](docs/kubernetes/service-discovery.md)) gestionan el descubrimiento de servicios. Los servicios externos son opcionales para la mayoría de los despliegues:

| Despliegue | etcd | NATS | Notas |
|------------|------|------|-------|
| **Desarrollo local** | ❌ No requerido | ❌ No requerido | Pasa `--discovery-backend file`; vLLM también necesita `--kv-events-config '{"enable_kv_cache_events": false}'` |
| **Kubernetes** | ❌ No requerido | ❌ No requerido | Descubrimiento nativo de K8s; plano de solicitudes TCP |

> **Nota:** El enrutamiento consciente de KV no requiere NATS. Habilita eventos KV cuando necesites seguimiento del estado de caché respaldado por eventos, o usa `--no-router-kv-events` para enrutamiento basado en predicción sin infraestructura externa de eventos.

Para Slurm u otros despliegues distribuidos que elijan modos respaldados por etcd o NATS JetStream:

- [etcd](https://etcd.io/) puede ejecutarse directamente como `./etcd`.
- [nats](https://nats.io/) necesita JetStream habilitado: `nats-server -js`.

Para configurar ambos rápidamente: `docker compose -f dev/docker-compose.yml up -d`

## Más noticias

- [11/20] [Dell integra PowerScale con NIXL de Dynamo para un TTFT 19x más rápido](https://www.dell.com/en-us/dt/corporate/newsroom/announcements/detailpage.press-releases~usa~2025~11~dell-technologies-and-nvidia-advance-enterprise-ai-innovation.htm)
- [11/20] [WEKA se asocia con NVIDIA en almacenamiento de caché KV para Dynamo](https://siliconangle.com/2025/11/20/nvidia-weka-kv-cache-solution-ai-inferencing-sc25/)
- [11/13] [Lista de reproducción de Office Hours de Dynamo](https://www.youtube.com/playlist?list=PL5B692fm6--tgryKu94h2Zb7jTFM3Go4X)
- [10/16] [Cómo Baseten logró inferencia 2x más rápida con NVIDIA Dynamo](https://www.baseten.co/blog/how-baseten-achieved-2x-faster-inference-with-nvidia-dynamo/)
- [12/01] [InfoQ: NVIDIA Dynamo simplifica el despliegue en Kubernetes para inferencia de LLM](https://www.infoq.com/news/2025/12/nvidia-dynamo-kubernetes/)

</details>

## Referencia

- **[Matriz de soporte](https://docs.nvidia.com/dynamo/resources/support-matrix)** — Hardware, SO, CUDA y versiones de backend
- **[Matriz de características](https://docs.nvidia.com/dynamo/resources/feature-matrix)** — Compatibilidad detallada de backends
- **[Artefactos de versión](https://docs.nvidia.com/dynamo/resources/release-artifacts)** — Contenedores, wheels, charts de Helm
- **[Descubrimiento de servicios](https://docs.nvidia.com/dynamo/kubernetes-deployment/advanced-platform/service-discovery)** — Descubrimiento nativo de K8s frente a etcd frente a basado en archivos
- **[Guía de benchmarking](https://docs.nvidia.com/dynamo/user-guides/benchmarking)** — Compara topologías de despliegue con AIPerf

<!-- Enlaces de referencia para la matriz de compatibilidad de características -->
[disagg]: docs/design-docs/disagg-serving.md
[kv-routing]: docs/components/router/README.md
[planner]: docs/components/planner/planner-guide.md
[kvbm]: docs/components/kvbm/README.md
[migration]: docs/fault-tolerance/request-migration.md
[lora]: examples/backends/vllm/deploy/lora/README.md
[tools]: docs/tool-calling/README.md
