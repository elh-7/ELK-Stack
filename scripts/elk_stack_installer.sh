#!/usr/bin/env bash
# Uso ./elk_stack_installer.sh

# Crear namespace
kubectl create namespace logging --dry-run=client -o yaml | kubectl apply -f -

# Aplicar manifiestos EFK
cat <<'EOF' | kubectl apply -f -

# ========================
# ELASTICSEARCH SERVICE
# ========================
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: logging
spec:
  clusterIP: None
  ports:
    - port: 9200
      name: rest
    - port: 9300
      name: inter-node
  selector:
    app: elasticsearch

# ========================
# ELASTICSEARCH STATEFULSET
# ========================
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: logging
spec:
  serviceName: "elasticsearch"
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.17.4
        ports:
        - containerPort: 9200
        - containerPort: 9300
        env:
        - name: cluster.name
          value: "efk-cluster"
        - name: node.name
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: discovery.seed_hosts
          value: "elasticsearch-0.elasticsearch.logging.svc.cluster.local,elasticsearch-1.elasticsearch.logging.svc.cluster.local,elasticsearch-2.elasticsearch.logging.svc.cluster.local"
        - name: cluster.initial_master_nodes
          value: "elasticsearch-0,elasticsearch-1,elasticsearch-2"
        - name: network.host
          value: "0.0.0.0"
        - name: ES_JAVA_OPTS
          value: "-Xms512m -Xmx512m"
        - name: xpack.security.enabled
          value: "true"
        - name: xpack.security.authc.api_key.enabled
          value: "true"
        - name: ELASTIC_PASSWORD
          value: "TuPasswordSeguro"
        - name: xpack.security.transport.ssl.enabled
          value: "true"
        - name: xpack.security.transport.ssl.verification_mode
          value: "certificate"
        - name: xpack.security.transport.ssl.key
          value: "/usr/share/elasticsearch/config/certs/elasticsearch.key"
        - name: xpack.security.transport.ssl.certificate
          value: "/usr/share/elasticsearch/config/certs/elasticsearch.crt"
        - name: xpack.security.transport.ssl.certificate_authorities
          value: "/usr/share/elasticsearch/config/certs/ca.crt"
        - name: xpack.security.http.ssl.enabled
          value: "true"
        - name: xpack.security.http.ssl.key
          value: "/usr/share/elasticsearch/config/certs/elasticsearch.key"
        - name: xpack.security.http.ssl.certificate
          value: "/usr/share/elasticsearch/config/certs/elasticsearch.crt"
        - name: xpack.security.http.ssl.certificate_authorities
          value: "/usr/share/elasticsearch/config/certs/ca.crt"
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
        - name: certs
          mountPath: /usr/share/elasticsearch/config/certs
          readOnly: true
      volumes:
      - name: certs
        secret:
          secretName: elastic-certs
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-csi
      resources:
        requests:
          storage: 10Gi

# ========================
# FLUENTD RBAC
# ========================
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
rules:
- apiGroups: [""]
  resources: ["pods", "namespaces"]
  verbs: ["get","list","watch"]

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: logging

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluentd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluentd
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: logging

# ========================
# FLUENTD CONFIGMAP
# ========================
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: logging
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      format multiline
      format_firstline /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
      format1 /^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[FP]) (?<message>.*)$/
      time_format %Y-%m-%dT%H:%M:%S.%N%:z
    </source>

    <match kubernetes.**>
      @type elasticsearch
      host elasticsearch
      port 9200
      scheme https
      ssl_verify false
      user elastic
      password TuPasswordSeguro
      index_name fluentd
      logstash_format true
      include_tag_key true
      tag_key @log_name
    </match>

# ========================
# FLUENTD DAEMONSET
# ========================
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: logging
  labels:
    app: fluentd
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1-debian-elasticsearch
        resources:
          limits:
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: config
          mountPath: /fluentd/etc
        - name: varlog
          mountPath: /var/log
        - name: dockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: config
        configMap:
          name: fluentd-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: dockercontainers
        hostPath:
          path: /var/lib/docker/containers


# ========================
# KIBANA DEPLOYMENT + SERVICE
# ========================
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:7.17.4
        ports:
        - containerPort: 5601
        env:
        - name: ELASTICSEARCH_HOSTS
          value: '["https://elasticsearch:9200"]'
        - name: ELASTICSEARCH_USERNAME
          value: "elastic"
        - name: ELASTICSEARCH_PASSWORD
          value: "TuPasswordSeguro"
        - name: SERVER_SSL_ENABLED
          value: "false"
        - name: ELASTICSEARCH_SSL_VERIFICATIONMODE
          value: "none"

---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: logging
spec:
  type: NodePort
  ports:
  - port: 5601
    targetPort: 5601
    nodePort: 30001
  selector:
    app: kibana

# ========================
# POD CERTIFICADOS
# ========================
---
apiVersion: v1
kind: Pod
metadata:
  name: elastic-cert-gen
  namespace: logging
spec:
  containers:
  - name: elasticsearch
    image: docker.elastic.co/elasticsearch/elasticsearch:7.17.4
    command: ["/bin/sh", "-c", "sleep 3600"]
  restartPolicy: Never
EOF
