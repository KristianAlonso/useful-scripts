# Comandos de configuración de Google Cloud

## Storage Buckets

### Configurar GCloud para que apúnte a un proyecto en específico

Ver: [gcloud config set](https://cloud.google.com/sdk/gcloud/reference/projects/list#EXAMPLES)

Enlistar los proyectos

```batch
gcloud projects list --sort-by=projectId
```

Ver: [gcloud config set](https://cloud.google.com/sdk/gcloud/reference/config/set#EXAMPLES)

Seleccionar un proyecto

```batch
gcloud config set project PROJECT_ID
```

### Configurar CORS

> Ver:
>
> - [Visualiza la configuración de CORS de un bucket](https://cloud.google.com/storage/docs/using-cors?hl=es-419#viewing-cors-bucket)
> - [Establece la configuración de CORS en un bucket](https://cloud.google.com/storage/docs/using-cors?hl=es-419#configure-cors-bucket)

Actualizar la configuración de CORS en un bucket usando un archivo `*.json`

```batch
gcloud storage buckets update gs://BUCKET_NAME --cors-file=./gs_aliaddo_cors_conf.json
```

Estructura del archivo

```json
[
  {
    "maxAgeSeconds": 3600,
    "method": [
      "HEAD",
      "GET",
      "OPTIONS"
    ],
    "origin": [
      "https://app.aliaddo.com"
    ],
    "responseHeader": [
      "Content-Type",
      "Access-Control-Allow-Origin"
    ]
  }
]
```

> `maxAgeSeconds` Es la cantidad de segundos que durará la caché.\
> `origin` Es un array con los dominios permitidos.\
> `responseHeader` Es un array con los headers que se le envían al navegador.
