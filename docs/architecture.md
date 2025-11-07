# 🧩 Elasticsearch Components

![Elasticsearch Components](<img width="1025" height="577" alt="image" src="https://github.com/user-attachments/assets/2ba47f8c-ef7b-4d7e-bd86-5ac538c43014" />
)

> Diagrama explicativo de la arquitectura interna de **Elasticsearch**, mostrando la relación entre *cluster*, *nodos*, *shards*, *réplicas* e *índices*.

---

## 📘 Descripción general

**Elasticsearch** es un motor de búsqueda y análisis distribuido basado en **Apache Lucene**.  
Su diseño permite almacenar, buscar y analizar grandes volúmenes de datos casi en tiempo real.

El diagrama anterior ilustra cómo los datos son organizados y distribuidos dentro del clúster.

---

## 🏗️ Estructura del Clúster

### 🔹 Cluster
- Es el conjunto completo de nodos de Elasticsearch que trabajan de forma coordinada.
- Cada clúster tiene un **nombre único** (por ejemplo, `efk-cluster`).
- Dentro del clúster, uno de los nodos es elegido como **nodo maestro**, encargado de:
  - Administrar la configuración global.
  - Supervisar el estado de los nodos.
  - Coordinar la creación y asignación de *shards*.

### 🔹 Nodes
- Un **nodo** es una instancia individual de Elasticsearch en ejecución (por ejemplo, un Pod en Kubernetes).
- Cada nodo almacena una parte de los datos y participa en el procesamiento de consultas.
- Existen diferentes tipos de nodos:
  - 🧭 **Master Node:** coordina el clúster.
  - 📦 **Data Node:** almacena datos y ejecuta operaciones de búsqueda y agregación.
  - 🔍 **Ingest Node:** realiza transformaciones de datos antes del indexado.
  - 🧱 **Coordinating Node:** distribuye las consultas entrantes entre los nodos de datos.

---

## 📂 Organización de los datos

### 🔸 Index
- Un **índice** es una colección lógica de documentos relacionados.
- Equivale a una “base de datos” en el mundo relacional.
- Cada índice está dividido en múltiples **shards** (fragmentos).

### 🔸 Shards
- Un **shard** es una unidad física de almacenamiento y procesamiento dentro del índice.
- Permite dividir los datos de un índice en fragmentos más pequeños para distribuir la carga entre nodos.
- Existen dos tipos:
  - **Primary Shard:** almacena los datos originales.
  - **Replica Shard:** copia exacta de un *primary shard* que proporciona tolerancia a fallos y balanceo de lectura.

### 🔸 Replicas
- Las **réplicas** se distribuyen en diferentes nodos para garantizar la alta disponibilidad.
- Si un nodo falla, otro nodo con la réplica puede continuar sirviendo consultas.

---

## 📜 Documentos y Campos

- Un **documento** representa la unidad mínima de información que puede ser indexada.
- Cada documento contiene múltiples **campos** (equivalentes a columnas en una base de datos relacional).
- Los documentos se almacenan en índices, y los índices se dividen en shards, que son manejados por los nodos del clúster.

---

## ⚙️ Flujo de datos resumido

1. **El clúster** coordina todos los nodos.
2. **Los nodos** almacenan shards del índice y procesan consultas.
3. **Los shards** dividen los índices para distribuir la carga.
4. **Las réplicas** aseguran disponibilidad y redundancia.
5. **Los documentos** son almacenados dentro de los shards, y sus **campos** permiten búsquedas rápidas y precisas.

---

## 🚀 Beneficios de esta arquitectura

- **Escalabilidad horizontal:** se pueden añadir más nodos fácilmente.
- **Alta disponibilidad:** gracias a las réplicas distribuidas.
- **Rendimiento optimizado:** consultas y escrituras paralelas.
- **Recuperación ante fallos:** los datos se mantienen disponibles incluso si un nodo cae.

---

# Arquitectura y Flujo de Datos en **Fluentd**

![Fluentd Data Flow](<img width="911" height="291" alt="image" src="https://github.com/user-attachments/assets/af4dca37-1fe3-4e0a-ac61-573c4d74d5f8" />
)

## 📘 Introducción

**Fluentd** es un recolector de datos de código abierto que unifica la recopilación y el consumo de logs.  
Permite tomar datos desde múltiples fuentes, transformarlos, y enviarlos hacia distintos destinos como bases de datos, sistemas de almacenamiento o herramientas de análisis (por ejemplo, Elasticsearch o Kibana).

Su arquitectura se basa en un flujo flexible compuesto por tres etapas principales:

> **Input → Filter → Output**

---

## 🧩 Componentes Principales

### 1. **Input (Entrada)**

El bloque **Input** representa la fase inicial del procesamiento.  
Aquí Fluentd **recibe datos desde diversas fuentes**, como:

- Archivos de log del sistema (`/var/log/...`)
- Aplicaciones que generan eventos o métricas
- Bases de datos o sockets TCP/UDP
- Herramientas de monitoreo o pipelines de datos

Cada fuente se define mediante un **plugin de entrada** (`in_*`), como por ejemplo:
```bash
<source>
  @type tail
  path /var/log/syslog
  tag system.logs
</source>
````

🔹 *Función:* Capturar los datos sin alterar su contenido, asignarles una etiqueta (`tag`) y enviarlos al siguiente paso del flujo.

---

### 2. **Filter (Filtro)**

El bloque **Filter** se encarga de **transformar, estructurar o enriquecer los datos** antes de enviarlos al destino.

Algunas tareas comunes incluyen:

* Parseo de formato (JSON, CSV, texto plano, etc.)
* Extracción de campos específicos
* Anonimización de información sensible
* Enriquecimiento con metadatos adicionales (por ejemplo, nombre del host o timestamp formateado)

Ejemplo:

```bash
<filter system.logs>
  @type record_transformer
  <record>
    hostname ${hostname}
  </record>
</filter>
```

🔹 *Función:* Asegurar que los datos tengan una estructura coherente y lista para su análisis posterior.

---

### 3. **Output (Salida)**

El bloque **Output** define **a dónde se envían los datos procesados**.
Fluentd soporta una gran variedad de destinos mediante plugins (`out_*`), entre ellos:

* **Elasticsearch** → para búsqueda y visualización con Kibana
* **S3 / GCS** → para almacenamiento a largo plazo
* **Prometheus / Loki** → para monitoreo
* **stdout / archivo** → para depuración o testing

Ejemplo:

```bash
<match system.logs>
  @type elasticsearch
  host elasticsearch.logging.svc
  port 9200
  index_name fluentd-logs
</match>
```

🔹 *Función:* Enviar los datos transformados hacia su destino final para almacenamiento o análisis.

---

## 🧠 Flujo de Datos Resumido

1. **Data** — Se genera en aplicaciones, servidores o contenedores.
2. **Input** — Fluentd recibe los logs mediante un plugin de entrada.
3. **Filter** — Los datos se transforman o enriquecen según las reglas configuradas.
4. **Output** — Se entregan al sistema de destino (por ejemplo, Elasticsearch).
5. **Destination** — Los datos son analizados o almacenados de forma permanente.

---

## ⚙️ Ventajas de Fluentd

* Modularidad mediante **plugins** (más de 500 disponibles).
* Manejo eficiente de datos estructurados y no estructurados.
* Integración directa con el **ELK/EFK Stack**.
* Alta tolerancia a fallos y bufferización configurable.
* Soporte para enrutar datos según etiquetas o patrones.

---

## 📚 Conclusión

Fluentd actúa como un **intermediario inteligente** entre las fuentes de datos y sus destinos finales, asegurando un transporte confiable y flexible de la información.
Gracias a su arquitectura basada en *Input → Filter → Output*, permite construir pipelines robustos de observabilidad dentro de entornos **Kubernetes**, **Docker** o sistemas distribuidos.

---

# Visualización y Análisis de Datos con **Kibana**

![Kibana Data Visualization](<img width="2814" height="1154" alt="image" src="https://github.com/user-attachments/assets/f4b790f7-3873-42a2-baa8-2d87bf97d3f0" />
)

## 📘 Introducción

**Kibana** es la interfaz de visualización y análisis de datos del ecosistema **Elastic Stack (ELK)**.  
Permite explorar, visualizar y comprender grandes volúmenes de información almacenados en **Elasticsearch**, mediante gráficos interactivos, dashboards y herramientas de monitoreo en tiempo real.

Kibana es la capa final del flujo **Input → Storage → Visualization**, funcionando como el **punto de acceso visual** a los datos procesados por **Fluentd** o **Logstash** y almacenados por **Elasticsearch**.

---

## 🧩 Componentes Principales

### 1. **Data Source (Fuente de datos)**

Los datos provienen del motor de búsqueda **Elasticsearch**, que indexa documentos y estructuras de información previamente recolectadas por herramientas como **Fluentd** o **Logstash**.

Cada índice en Elasticsearch representa un conjunto de datos que Kibana puede consultar y visualizar.  
El vínculo entre ambos se establece mediante un **Index Pattern**, que define qué índices se usarán en los dashboards.

Ejemplo:
```bash
Index Pattern: logs-* 
````

🔹 *Función:* Proveer la información ya indexada y estructurada que Kibana transformará en gráficos, tablas y reportes.

---

### 2. **Discover (Explorar Datos)**

El módulo **Discover** permite **examinar datos sin procesar** directamente desde Elasticsearch.
A través de filtros, campos y búsquedas con la sintaxis de consulta **Lucene** o **KQL (Kibana Query Language)**, el usuario puede:

* Navegar registros cronológicamente.
* Ver los campos individuales de cada documento.
* Exportar consultas o resultados para análisis adicionales.

Ejemplo de búsqueda en KQL:

```bash
status_code >= 400 AND response_time > 1000
```

🔹 *Función:* Brindar una vista granular de los registros para entender el contexto antes de construir visualizaciones.

---

### 3. **Visualize (Visualizaciones)**

El módulo **Visualize** permite **crear representaciones gráficas interactivas** basadas en los datos indexados.
Soporta múltiples tipos de gráficos:

* Barras, líneas y áreas
* Mapas de calor y geográficos
* Tabelas dinámicas y métricas numéricas
* Series temporales (TSVB)

Cada visualización puede alimentarse de una o varias consultas de Elasticsearch y ser reutilizada en paneles.

🔹 *Función:* Convertir los datos en información visual fácilmente interpretable.

---

### 4. **Dashboard (Paneles de control)**

Los **Dashboards** agrupan varias visualizaciones para **proporcionar una vista consolidada del sistema**.
Pueden configurarse para mostrar métricas de infraestructura, rendimiento de aplicaciones o seguridad, todo en tiempo real.

Los paneles pueden incluir:

* Filtros dinámicos (por tiempo, host, servicio, etc.)
* Vistas en tiempo real actualizadas automáticamente
* Alertas visuales ante anomalías o errores

Ejemplo de uso:

> Un dashboard de monitoreo de Kubernetes mostrando el consumo de CPU, logs de contenedores y errores HTTP 500.

🔹 *Función:* Facilitar el monitoreo integral y la toma de decisiones basada en datos.

---

### 5. **Alerts & Reports (Alertas y Reportes)**

Kibana permite **crear alertas automáticas** que se activan según condiciones definidas sobre los datos.
Estas alertas pueden enviar notificaciones por correo, Slack u otros canales cuando se detecten eventos críticos.

Además, se pueden generar **reportes PDF o CSV** programados desde dashboards o visualizaciones.

Ejemplo:

```bash
Trigger: response_time > 2000ms
Action: Send Slack alert to #devops
```

🔹 *Función:* Automatizar la observación y comunicación de eventos relevantes dentro de la infraestructura.

---

## 🔄 Flujo de Datos en el ELK Stack

1. **Fluentd / Logstash** recolectan y procesan los logs.
2. **Elasticsearch** indexa y almacena los datos.
3. **Kibana** los consulta, filtra y visualiza en paneles interactivos.
4. Los usuarios exploran, analizan y crean alertas para observabilidad continua.

---

## ⚙️ Ventajas de Kibana

* Visualización **en tiempo real** de datos de Elasticsearch.
* Integración nativa con los demás componentes del **Elastic Stack**.
* Potente lenguaje de consultas (**KQL / Lucene**).
* Amplio catálogo de **gráficos y visualizaciones personalizables**.
* Soporte para **alertas, reportes y machine learning**.
* Compatible con **roles, usuarios y seguridad granular** (X-Pack).

---

## 📚 Conclusión

**Kibana** es la capa de observabilidad visual dentro del **ELK/EFK Stack**.
Permite convertir datos complejos en conocimiento útil a través de dashboards interactivos, detección de anomalías y análisis temporal.

En entornos modernos —como **Kubernetes**, **microservicios** o **infraestructura cloud**—, Kibana se convierte en una herramienta esencial para la **analítica, monitoreo y diagnóstico operacional**.

---
© 2025 — Elaborado para documentación técnica de despliegue **EFK (Elasticsearch, Fluentd, Kibana)** en entornos Kubernetes por Axel Bautista y Emanuel López - UNAM FI 
