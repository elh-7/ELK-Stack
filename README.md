# ELK-Stack + Documentación Integrada (Observability)
# 🎯 Descripción del proyecto

ELK Stack es el acrónimo de tres herramientas integradas: Elasticsearch, Logstash (o Fluentd como alternativa) y Kibana.

Con ellas se construye una plataforma de observabilidad, capaz de recolectar, procesar, almacenar, analizar y visualizar grandes volúmenes de datos principalmente logs, métricas y eventos de seguridad.

El propósito fundamental de este proyecto final para el Diplomado de Infraestructura en Tecnologías de la Información es implementar ELK Stack para centralizar la información de todos los sistemas, permitiendo detectar anomalías, correlacionar eventos, crear alertas y generar reportes visuales en tiempo real en un entorno completamente virtualizado.

# 👥 Integrantes del equipo
  - Axel Bautista
  - Emanuel López

# 🔧 Prerrequisitos (versiones de software)
  1. Rocky Linux 9.6 o Alma Linux 9
  2. Elasticsearch 7.17.4
  3. Flunted v1-debian-elasticsearch 6d7521c55bc7
  4. Kibana 7.17.4

# 🔧 Prerrequisitos de hardware

  Consulte: https://www.elastic.co/docs/deploy-manage/deploy/cloud-enterprise/ece-hardware-prereq
  **NOTA IMPORTANTE:**
  Considere la cantidad de nodos que va a desplegar para cubrir los requerimientos de hardware, la documentación indica que los recursos están pensados para un solo nodo. 

# 🔗 Referencias y documentación

Documentación oficial y fuentes técnicas primarias

Elastic. (2024). Elastic Observability: Documentation. Elastic.co. Recuperado de https://www.elastic.co/guide/en/observability/current/index.html

Elastic. (2024). Logstash Reference Documentation. Elastic.co. Recuperado de https://www.elastic.co/guide/en/logstash/current/index.html

Elastic. (2024). Kibana Guide. Elastic.co. Recuperado de https://www.elastic.co/guide/en/kibana/current/index.html

Fluentd. (2024). Fluentd Documentation. Treasure Data, Inc. Recuperado de https://docs.fluentd.org/

Prometheus Authors. (2024). Prometheus Documentation. The Prometheus Authors. Recuperado de https://prometheus.io/docs/

Grafana Labs. (2024). Grafana Documentation. Grafana Labs. Recuperado de https://grafana.com/docs/

Cloud Native Computing Foundation (CNCF). (2024). Jaeger: Open Source, End-to-End Distributed Tracing. CNCF.Recuperado de https://www.jaegertracing.io/docs/

OpenTelemetry Authors. (2024). OpenTelemetry Documentation. Cloud Native Computing Foundation. Recuperado de https://opentelemetry.io/docs/

Prometheus Authors. (2024). Alertmanager Guide. The Prometheus Authors. Recuperado de https://prometheus.io/docs/alerting/latest/alertmanager/

Yelp Engineering. (2023). ElastAlert 2 Documentation. Yelp Inc. Recuperado de https://elastalert2.readthedocs.io/en/latest/

Fuentes de referencia complementaria

Red Hat. (2024). Understanding Observability in Kubernetes. Red Hat, Inc. Recuperado de https://www.redhat.com/en/topics/observability

CNCF. (2024). Cloud Native Observability Landscape Report. Cloud Native Computing Foundation. Recuperado de https://landscape.cncf.io/

Docker Inc. (2024). Docker Logging and Monitoring Overview. Docker Docs. Recuperado de https://docs.docker.com/config/containers/logging/

# 📦 Instalación paso a paso y Configuración

Para desplegar el proyecto ELK-Stack, revise detenidamente el apartado de docs para consultar los manuales de instalación. Una vez revisado y comprendido su contenido ejecute los scrips en el siguiente orden. Recuerde tener privilegios de administrador y que el scrip tenga permisos de ejecución. Puede apoyarse de: 

chmod +x nombre_del_scrip.sh  -> para darle permiso de ejecución
./nombre_del_scrip.sh -> para la ejecución

**Orden de ejecución**

1. kubernetes_installer.sh
2. nfs_installer.sh
3. elk_stack_despliegue.sh
4. certificados.sh

