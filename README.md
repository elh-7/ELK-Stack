# ELK-Stack + Documentación Integrada (Observability)
# 🎯 Descripción del proyecto

ELK Stack es el acrónimo de tres herramientas integradas: Elasticsearch, Logstash (o Fluentd como alternativa) y Kibana.

Con ellas se construye una plataforma de observabilidad, capaz de recolectar, procesar, almacenar, analizar y visualizar grandes volúmenes de datos principalmente logs, métricas y eventos de seguridad.

El propósito fundamental de este proyecto final para el Diplomado de Infraestructura en Tecnologías de la Información es implementar ELK Stack para centralizar la información de todos los sistemas, permitiendo detectar anomalías, correlacionar eventos, crear alertas y generar reportes visuales en tiempo real en un entorno completamente virtualizado.

<p align="center">
  <img width="624" height="438" alt="image" src="https://github.com/user-attachments/assets/f2a7cfb8-23ab-4f7f-aced-7748c9252531" />
</p>


# 👥 Integrantes del equipo
  - Axel Bautista
  - Emanuel López

# 🔧 Pre-requisitos (versiones de software)
  1. Rocky Linux 9.6 o Alma Linux 9
  2. Elasticsearch 7.17.4
  3. Flunted v1-debian-elasticsearch 6d7521c55bc7
  4. Kibana 7.17.4

# 🔧 Pre-requisitos de hardware

  Consulte: https://www.elastic.co/docs/deploy-manage/deploy/cloud-enterprise/ece-hardware-prereq
  
  **NOTA IMPORTANTE:**
  
  Considere la cantidad de nodos que va a desplegar para cubrir los requerimientos de hardware, la documentación indica que los recursos están pensados para un solo nodo. 

# 📦 Instalación paso a paso y Configuración

Para desplegar el proyecto ELK-Stack, revise detenidamente el apartado de docs para consultar los manuales de instalación. Una vez revisado y comprendido su contenido ejecute los scrips en el siguiente orden. Recuerde tener privilegios de administrador y que el scrip tenga permisos de ejecución. Puede apoyarse de: 

chmod +x nombre_del_scrip.sh  -> para darle permiso de ejecución

./nombre_del_scrip.sh -> para la ejecución

**Orden de ejecución**

1. kubernetes_installer.sh
2. nfs_installer.sh
3. elk_stack_installer.sh
4. certificados_elasticsearch.sh

# 🐛 Troubleshooting

**1. Problema de comunicacion entre pods**

_Descripcion:_ Es comun que con la configuracion por defecto de calico y kubernetes los pods que se creen puedan verse hacia el exterior pero no entre si por lo cual para resolver este proble hay dos opciones

_Solucion temporal:_ Apagar el firewall, esta obviamente es una solucion temporal que puede ayudar en caso de tratar de ubicar el problema

_Solucion Permanente._ Hay que llevar a cabo la apertura de los puertos correspondientes, para que los nodos no queden expuestos en el resto de elementos

**2. Problema de permisos para el almacenamiento permanente**

Por las configuraciones que se manejan los servicios, es posible que al momento de la creacion puedan faltar problemas por las condiciones de carrera que existen al momento de ejecutar los scripts dados, por lo cual en caso de que los logs de los pods de elastic search muestren que el acceso a los recursos necesarios no es permitido hay que ejecutar los siguientes comandos: 

_sudo chown -R 1000:1000 /srv/nfs/k8s-storage/_

_sudo chmod -R 777 /srv/nfs/k8s-storage_

**3. Problema de conectividad entre nodos para instalacion de cluster**

Dependiendo del sistema que se este creando, es posible que pueda ocurrir un error en la instalacion de kubernetes, ya sea porque no es posible comunicarse para crear el cluster o que posteriormente se pierda conectividad.Para este caso lo mejor es usar redes bridges que puedan recibir y transmitir informacion de internet asi como ver los otros nodos, o en su defecto configuraciones nats que se puedan ver entre ellas, debido a que por la configuracion de red puede llegar a pasar que aunque los nodos puedan conectarse a internet no tengan comunicacion entre si.

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


