"""Update raw_tables.sql: correct bucket + add trailing slash on schema locations."""
p = "data-platform/trino/init/raw_tables.sql"
s = open(p, encoding="utf-8").read()
s = s.replace("s3://de-project-commission/raw/", "s3://quocbv-fraud-data/raw/")
# add trailing slash for schema locations
s = s.replace("raw/SSI_Common'", "raw/SSI_Common/'")
s = s.replace("raw/SSI_Equity'", "raw/SSI_Equity/'")
s = s.replace("raw/SSI_Derivatives'", "raw/SSI_Derivatives/'")
s = s.replace("raw/SSI_OEF'", "raw/SSI_OEF/'")
open(p, "w", encoding="utf-8").write(s)
print("quocbv count:", s.count("quocbv-fraud-data"))
print("remaining de-project:", s.count("de-project-commission"))
print("SSI_Common slash:", s.count("raw/SSI_Common/'"))
print("SSI_Common no-slash:", s.count("raw/SSI_Common'"))