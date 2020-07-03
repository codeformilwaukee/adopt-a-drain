1. Make new folder in `data/` for shapefiles
2. Copy shapefiles (.cpg, .dbf, .prj, .sbn, .sbx, .shp, .shx) into folder
3. Convert shapefiles to SQL with shp2pgsql. Most have SRID 32054 (`NAD_1983_StatePlane_Wisconsin_South_FIPS_4803_Feet`), but double check the .shp file.
4. Load shapes into temporary database table with `psql`and newly generated SQL
5. Select rows from temporary table into CSV with columns `city_name`, `city_id`, `lat`, `lng`. This may vary due to the structure of the files provided.
6. Update `lib/tasks/data.rake` to import the newly created file
7. Commit the CSV to the git repository

```sh
# Characters in UPPERCASE represent a placeholder in an example command
# Step 3: shp2pgsql -s 32054 FILE.shp TEMP_TABLE_NAME > TEMP_SQL_SCRIPT.sql
shp2pgsql -s 32054 Storm_Catch_Basins.shp cedarburg_drains > cedarburg_drains.sql

# Step 4: psql -d TEMP_DATABASE_NAME -f TEMP_SQL_SCRIPT.sql
psql -d temp_drains -f cedarburg_drains.sql

# Step 5: psql -c "\copy (select 'CITY NAME' as city_name, gid as city_id, ST_Y(ST_Transform(geom, 4326)) as lat, ST_X(ST_Transform(geom, 4326)) as lng from TEMP_TABLE_NAME) TO ./CSV_EXPORT.csv CSV HEADER;" -d TEMP_DATABASE_NAME
psql -c "\copy (select 'Cedarburg' as city_name, gid as city_id, ST_Y(ST_Transform(geom, 4326)) as lat, ST_X(ST_Transform(geom, 4326)) as lng from cedarburg_drains) TO ./data/cedarburg_drains.csv CSV HEADER;" -d temp_drains
```
