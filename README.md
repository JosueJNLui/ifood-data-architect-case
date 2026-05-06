# 🚕 iFood Data Architect Case — NYC Taxi Trips

Pipeline de dados end-to-end que faz a ingestão de corridas de táxi (Yellow e Green Cabs) da [NYC Open Data API](https://data.cityofnewyork.us/), armazena em camadas **Bronze → Silver → Gold** (arquitetura Medallion) e disponibiliza os dados tratados para análises no Databricks.

---

## 📐 Arquitetura

```
NYC Open Data API
       │
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│    Bronze    │ ──▶ │    Silver    │ ──▶ │     Gold     │
│  (raw data)  │     │  (cleansed)  │     │   (curated)  │
└──────────────┘     └──────────────┘     └──────────────┘
   S3 + Delta          DLT Pipeline         DLT Pipeline
                      + Data Quality
```

| Camada | Descrição | Notebook |
|--------|-----------|----------|
| **Bronze** | Ingestão crua da API via `sodapy`, com merge incremental (Delta Lake) no S3 | `src/01_bronze_api_ingestion.ipynb` |
| **Silver** | Tipagem de colunas, validação de qualidade (DLT Expectations) e quarentena de registros inválidos | `src/02_silver_taxi_ingestion_dq.ipynb` |
| **Gold** | Tabela fato `fact_taxi_trips` unificando Yellow e Green cabs com hash ID | `src/03_gold_taxi_fact.ipynb` |

---

## 🛠️ Tech Stack

| Tecnologia | Uso |
|---|---|
| **Databricks** | Notebooks, Unity Catalog, Delta Live Tables (DLT) |
| **PySpark** | Processamento distribuído de dados |
| **Delta Lake** | Armazenamento transacional (ACID) |
| **Terraform** | Provisionamento de infraestrutura AWS (buckets S3) |
| **Databricks Asset Bundles (DABs)** | Deploy e orquestração de jobs e pipelines |
| **sodapy** | Client Python para a Socrata Open Data API (NYC Open Data) |
| **AWS S3** | Storage das camadas Bronze e Metastore |

---

## ⚙️ Pré-requisitos

- [Terraform](https://www.terraform.io/downloads) `v1.14.1`
- [Databricks CLI](https://docs.databricks.com/dev-tools/cli/index.html) (com autenticação configurada)
- Conta AWS com credenciais configuradas
- App Token da [NYC Open Data](https://data.cityofnewyork.us/) (Socrata)
- Python 3.10+

---

## 📁 Estrutura do Projeto

```
.
├── src/                                    # Notebooks Databricks
│   ├── 00_setup_env.ipynb                  # Bootstrap do Unity Catalog (catalog + schemas)
│   ├── 01_bronze_api_ingestion.ipynb       # Ingestão Bronze (API → S3/Delta)
│   ├── 02_silver_taxi_ingestion_dq.ipynb   # Pipeline DLT Silver + Quarentena
│   └── 03_gold_taxi_fact.ipynb             # Pipeline DLT Gold (fact table)
│
├── resources/                              # Definições de Jobs/Pipelines (DABs)
│   ├── 01_bronze_api_ingestion.yml         # Job de ingestão Bronze
│   └── 02_silver_taxi_ingestion_dq.yml     # Pipeline DLT (Silver + Gold)
│
├── terraform/                              # IaC — provisionamento AWS
│   ├── backend.tf
│   ├── buckets.tf                          # Buckets S3 (bronze, metastore)
│   ├── config/
│   │   └── development.tfvars
│   ├── locals.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── versions.tf
│
├── analysis/                               # Análises de negócio (camada Gold)
│   └── 04_gold_business_insights.ipynb     # Perguntas de negócio (SQL)
│
├── .images/                                # Imagens e gráficos de evidência
│   ├── Average Passenger by Hour.png       # Gráfico de ocupação por hora
│   └── Dashboard Cabs - iFood Case.png    # Dashboard final no Databricks
│
├── databricks.yml                          # Configuração do Databricks Asset Bundle
├── requirements.txt                        # Dependências Python
└── README.md
```

---

## 🚀 Instruções de Execução

### 1. Clonar o repositório

```bash
git clone https://github.com/JosueJNLui/ifood-data-architect-case.git
cd ifood-data-architect-case
```

### 2. Provisionar infraestrutura (Terraform)

```bash
cd terraform

# Inicializar o Terraform
terraform init

# Selecionar o workspace
terraform workspace select development || terraform workspace new development

# Planejar as mudanças
terraform plan --var-file=config/development.tfvars -out=plan.tfplan

# Aplicar
terraform apply plan.tfplan
```

Isso criará os buckets S3 necessários para armazenar os dados (camadas bronze e metastore).

### 3. Configurar Databricks Secrets

Cadastre os secrets no scope `db-scope` do Databricks:

```bash
# Criar o scope (se ainda não existir)
databricks secrets create-scope db-scope

# Adicionar os secrets
databricks secrets put-secret db-scope aws_account_id --string-value "<seu_account_id>"
databricks secrets put-secret db-scope nyc_app_token  --string-value "<seu_app_token>"
```

### 4. Setup do Unity Catalog

Execute o notebook `src/00_setup_env.ipynb` no Databricks para criar o catálogo `logistics` e os schemas `bronze`, `silver` e `gold`.

### 5. Deploy dos Jobs e Pipelines (Databricks Asset Bundles)

```bash
# Validar o bundle
databricks bundle validate

# Deploy para o workspace
databricks bundle deploy -t development

# Executar o job de ingestão Bronze
databricks bundle run data-ingestion -t development
```

### 6. Executar o Pipeline DLT (Silver + Gold)

Após a ingestão Bronze, execute o pipeline DLT via UI do Databricks ou pelo CLI:

```bash
databricks bundle run dlt-logistics-pipeline -t development
```

O pipeline DLT irá:
1. Ler os dados Bronze (streaming)
2. Aplicar tipagem e regras de qualidade (Silver)
3. Separar registros inválidos em tabelas de quarentena
4. Gerar a tabela fato `gold.fact_taxi_trips` unificando Yellow e Green cabs

---

## 🔍 Regras de Data Quality (Silver)

| Regra | Condição | Ação |
|-------|----------|------|
| `valid_total_amount` | `total_amount >= 0` | Drop se inválido |
| `valid_passenger_count` | `passenger_count <= 4 AND passenger_count > 0` | Drop se inválido |
| `valid_trip_distance` | `trip_distance >= 0` | Drop se inválido |
| `consistent_timestamps` | `dropoff_datetime > pickup_datetime` | Drop se inválido |

> Registros que não passam nas validações são direcionados para tabelas de **quarentena** (`quarantine_yellow_taxi`, `quarantine_green_taxi`) com a coluna `quarantine_reason` indicando o motivo.

---

## 📈 Business Insights

As análises abaixo foram realizadas sobre a camada **Gold** (`logistics.gold.fact_taxi_trips`) através do notebook `analysis/04_gold_business_insights.ipynb`.

### Pergunta 1 — Média de Faturamento Mensal (Yellow Taxi)

> *Qual a média de valor total (`total_amount`) recebido em um mês considerando todos os yellow táxis da frota?*

```sql
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('MONTH', date_partition) dt_month,
        SUM(total_amount) monthly_sum
    FROM logistics.gold.fact_taxi_trips
    WHERE cabs_type = 'yellow_taxi'
    GROUP BY 1
)
SELECT
    ROUND(AVG(monthly_sum), 2) avg_total_amount_per_month
FROM monthly_revenue;
```

**✅ Resposta: `$ 84.898.762,32`**

---

### Pergunta 2 — Comportamento de Ocupação por Hora (Maio 2023)

> *Qual a média de passageiros (`passenger_count`) por cada hora do dia que pegaram táxi no mês de maio considerando todos os táxis da frota?*

```sql
SELECT
    LPAD(HOUR(pickup_datetime), 2, '0') || ':00' pickup_hour,
    ROUND(AVG(passenger_count), 2) avg_passenger_count
FROM logistics.gold.fact_taxi_trips
WHERE DATE_TRUNC('MONTH', date_partition) = '2023-05-01'
GROUP BY ALL
ORDER BY 1 ASC;
```

**✅ Resposta:**

![Média de passageiros por hora do dia em maio/2023](.images/Average%20Passenger%20by%20Hour.png)

> O gráfico mostra que a ocupação média é mais alta durante a madrugada (00h–03h, ~1,33–1,34 passageiros) e à noite (20h–23h, ~1,32–1,34), com o vale ocorrendo às 06h (~1,16 passageiros).

---

### 🖥️ Dashboard Final

![Dashboard iFood - Data Architect Case](.images/Dashboard%20Cabs%20-%20iFood%20Case.png)

---

## 📊 Datasets

| Dataset | Source | API Dataset ID |
|---------|--------|----------------|
| Yellow Taxi Trip Data | [NYC Open Data](https://data.cityofnewyork.us/Transportation/2023-Yellow-Taxi-Trip-Data/4b4i-vvec) | `4b4i-vvec` |
| Green Taxi Trip Data | [NYC Open Data](https://data.cityofnewyork.us/Transportation/2023-Green-Taxi-Trip-Data/peyi-gg4n) | `peyi-gg4n` |

---

## 📝 Licença

Este projeto foi criado como parte do case de Data Architect do iFood.
