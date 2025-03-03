#############################################################################~#
#### Community data for all funcab analyses                                ####
####                                                                       ##~#
#### project: FunCaB                                                       ##~#
#### author: Francesca Jaroszynska                                         ##~#
#### email: fjaroszynska@gmail.com                                         ##~#
#### edited: 03/11/2021                                                    ##~#
#############################################################################~#

# load required packages
source("R/load_packages.R")

library(DBI)
library(SDMTools)
library(RSQLite)

# source required dictionaries
source("R/community/dictionaries.R")

# connect to database
con <- src_sqlite(path = "data/community/raw/seedclim.sqlite", create = FALSE)

####-------- load seedclim data ---------####
FG <- tbl(con, "character_traits") %>%
  filter(trait == "functionalGroup") %>%
  select(species, functionalGroup = value) %>%
  collect()

my.GR.data <- tbl(con, "subTurfCommunity") %>%
  group_by(turfID, year, species) %>%
  summarise(n_subturf = n()) %>%
  collect() %>%
  full_join(tbl(con, "turfCommunity") %>% collect()) %>%
  left_join(tbl(con, "taxon"), copy = TRUE) %>%
  left_join(tbl(con, "turfs"), copy = TRUE) %>%
  left_join(tbl(con, "plots"), by = c("destinationPlotID" = "plotID"), copy = TRUE) %>%
  left_join(tbl(con, "blocks"), by = "blockID", copy = TRUE) %>%
  left_join(tbl(con, "sites"), by = "siteID", copy = TRUE) %>%
  left_join(tbl(con, "turfEnvironment"), copy = TRUE) %>%
  select(siteID, blockID, plotID = destinationPlotID, turfID, TTtreat, GRtreat, Year = year, species, cover, temperature_level, precipitation_level, recorder, totalVascular, totalBryophytes, vegetationHeight, mossHeight, litter) %>%
  mutate(TTtreat = factor(TTtreat), GRtreat = factor(GRtreat)) %>%
  ungroup() %>%
  filter(Year > 2014, TTtreat == "TTC"|GRtreat == "TTC")

# correct inconsistencies among cm/mm
my.GR.data <- my.GR.data %>%
  mutate(vegetationHeight = if_else(Year %in% c(2015, 2017), vegetationHeight*10, vegetationHeight),
         mossHeight = if_else(Year %in% c(2015, 2017), mossHeight*10, mossHeight)) %>%
  mutate(mossHeight = if_else(Year == 2017 & turfID == "301 TTC", 7.5, mossHeight))

# merge the GRtreat and TTtreat into one column
levels(my.GR.data$TTtreat) <- c(levels(my.GR.data$TTtreat),levels(my.GR.data$GRtreat))
my.GR.data$TTtreat[my.GR.data$TTtreat == ""| is.na(my.GR.data$TTtreat)] <- my.GR.data$GRtreat[my.GR.data$TTtreat == ""| is.na(my.GR.data$TTtreat)]
my.GR.data$GRtreat <- NULL

my.GR.data$recorder[is.na(my.GR.data$recorder)] <- "unknown botanist"


####------- fixes for botanist biases -------####
# Pascale fix
my.GR.data$cover[my.GR.data$recorder == "PM"] <- my.GR.data$cover[my.GR.data$recorder=="PM"]*1.20

# Siri fix
siri <- my.GR.data %>%
  filter(recorder == "Siri") %>%
  group_by(turfID, Year) %>%
  mutate(SumOfcover = sum(cover)) %>%
  filter(SumOfcover/totalVascular < 1.35)

siri.fix <- paste(as.character(my.GR.data$turfID), my.GR.data$Year) %in% paste(siri$turfID, siri$Year)
my.GR.data$cover[siri.fix] <- my.GR.data$cover[siri.fix]*1.3

# Owen fix
owen <- my.GR.data %>%
  filter(recorder == "Owen") %>%
  group_by(turfID, Year) %>%
  mutate(sumOfCover = sum(cover)) %>%
  filter(sumOfCover/totalVascular > 1.5)

owen.fix <- paste(as.character(my.GR.data$turfID), my.GR.data$Year) %in% paste(owen$turfID, owen$Year)
my.GR.data$cover[owen.fix] <- my.GR.data$cover[owen.fix]/1.5

my.GR.data <- my.GR.data %>%
  filter(turfID %in% dict_TTC_turf$TTtreat) %>% # or semi_join()
  mutate(Treatment = "C", TTtreat = turfID) %>%
  left_join(dict_TTC_turf, by = "TTtreat", suffix = c(".new", "")) %>%
  mutate(blockID = substr(turfID, 4, 4)) %>%
  select(-c(plotID, temperature_level, precipitation_level, totalVascular, litter, turfID.new)) %>%
  filter(!is.na(cover),
         !(TTtreat == "37 TTC" & Year > 2015))

# duplicating two plots that are missing from 2017
OvsSkj17 <- my.GR.data %>% filter(TTtreat %in% c("297 TTC", "246 TTC"), Year == 2016) %>%
  mutate(Year = 2017)

my.GR.data <- my.GR.data %>% bind_rows(OvsSkj17)


####-------- load funcab data ---------####
gudfun2015 <- read_excel("data/community/raw/funcab_Gudmedalen.xlsx", col_types = "text")

funcab_2015 <- read_delim("data/community/raw/funcab_composition_2015-utenGud.csv", delim = ";", col_types = cols(.default = "c"))

funcab_2016 <- read_delim("data/community/raw/funcab_composition_2016.csv", delim = ";", col_types = cols(.default = "c"))

funcab_2017 <- read_delim("data/community/raw/funcab_composition_2017.csv", delim = ";", col_types = cols(.default = "c"))

funcab_2018 <- read_excel("data/community/raw/funcab_composition_2018.xlsx", col_types = "text")

scBryo <- read_excel("data/community/raw/2017seedclimBryophyte.xlsx")


# calculate mean veg and moss heights for 2018
funcab_2018 <- funcab_2018 %>%
  filter(!grepl("TT1", TTtreat), !grepl("OUT", TTtreat), !grepl("OUT", turfID)) %>%
  mutate_at(vars(vegetationHeight, mossHeight), as.numeric) %>%
  group_by(turfID) %>%
  mutate(vegetationHeight = as.character(mean(vegetationHeight, na.rm = TRUE)),
         mossHeight =  as.character(mean(mossHeight, na.rm = TRUE))) %>%
  ungroup()

# replace species names where mistakes have been found in database
problems <- read.csv("data/community/raw/speciesCorrections.csv", sep = ";", stringsAsFactors = FALSE) %>%
  filter(!old %in% c("Vio.can", "Com.ten", "Sel.sel")) %>%
  filter(cover != "WHAT HAPPENED") %>%
  mutate(cover = as.numeric(cover))

# load the dictionary merger
mergedictionary <- read.csv2(file = "data/community/raw/mergedictionary.csv")

prob.sp <- problems %>%
  filter(!is.na(Year)) %>%
  select(-functionalGroup)

prob.sp.name <- problems %>%
  filter(is.na(Year), !old %in% c("Eri.bor")) %>%
  select(old, new) %>%
  bind_rows(mergedictionary)

problems.cover <- filter(problems, !is.na(cover)) %>%
  select(turfID, year = Year, species = old, cover)


# bind composition data, replace _ with . for compatibility in spp names
composition <- funcab_2016 %>%
  bind_rows(funcab_2015) %>%
  bind_rows(gudfun2015) %>%
  bind_rows(funcab_2017) %>%
  bind_rows(funcab_2018) %>%
  filter(subPlot %in% c("%", "T")) %>%
  select(c(siteID:subPlot), Year = year, recorder, c(totalGraminoids:mossHeight), litter, acro, pleuro, c(`Ach mil`:`Vis vul`)) %>%
  select_if(colSums(!is.na(.)) > 0) %>%
  gather(c("Ach mil":"Vio sp"), key = "species", value = "cover")

# create table of species presences in turfs
subTurfFreq <- composition %>%
  filter(subPlot == "T", !is.na(cover)) %>%
  select(siteID, Treatment, turfID, Year, species, presence = cover) %>%
  mutate(presence = 1)

# join species presences back onto full dataset
composition <- composition %>%
  filter(subPlot == "%") %>%
  left_join(subTurfFreq)


# overwrite problem spp with their correct names and covers
composition <- composition %>%
  mutate(species = gsub("\\ |\\_", ".", species)) %>%
  mutate_at(vars(cover, Year, totalGraminoids:pleuro), as.numeric) %>%
  left_join(prob.sp, by = c("Year", "turfID", "siteID", "species" = "old"), suffix = c("", ".new")) %>%
  mutate(species = coalesce(new, species),
         cover = coalesce(cover.new, cover, )) %>%
  select(-new, -cover.new, -subPlot) %>%
  left_join(prob.sp.name, by = c("species" = "old")) %>%
  mutate(species2 = if_else(!is.na(new), new, species)) %>%
  select(-species, -new) %>%
  rename(species = species2)


# adjust species, turf and site names
composition <- composition %>%
  left_join(dict_TTC_turf, by = c("turfID" = "TTtreat"), suffix = c(".old", ".new")) %>%
  mutate(turfID = if_else(!is.na(turfID.new), turfID.new, turfID)) %>%
  mutate(turfID = if_else((blockID == 16 & siteID == "Gudmedalen"), gsub("16", "5", turfID), turfID),
         turfID = if_else((siteID == "Alrust" & blockID == "3" & Year == 2015 & Treatment == "C"), "Alr3C", turfID),
         turfID = recode(turfID, "Alr4FGB" = "Alr5C"),
         turfID = recode(turfID, "Lav1G " = "Lav1G"),
         blockID = if_else(blockID == 16 & siteID == "Gudmedalen", gsub("16", "5", blockID), blockID),
         blockID = if_else(turfID == "Gud12C", "12", blockID)) %>%
  filter(!(blockID == "4" & Year == 2015 & siteID == "Alrust"),
         !(turfID =="Gud12C" & Year == 2015),
         !is.na(turfID),
         !(turfID == "Alr3C" & recorder == "Siri"))


FGBs <- composition %>%
  filter(Treatment %in% c("FGB", "GF")) %>%
  select(-species, -cover, -turfID.new) %>%
  distinct() %>%
  filter(Year > 2015)

# filter out funcab controls that are also TTCs in 2015 & 2016
ttcs1516 <- composition %>%
  filter(Treatment == "C", !Year %in% c(2017, 2018), !is.na(Year)) %>%
  right_join(dict_TTC_turf) %>%
  select(-species, -cover, -pleuro, -acro, -litter, -presence, -turfID.new, -recorder) %>%
  distinct()

ttcs17 <- composition %>%
  filter(Treatment == "C", Year == 2017) %>%
  right_join(dict_TTC_turf) %>%
  select(-turfID.new, -cover, -presence, -species) %>%
  distinct() %>%
  full_join(scBryo, by = "turfID", suffix = c(".old", "")) %>%
  select(-totalBryophytes.old, -mossHeight.old, -vegetationHeight.old, -TTtreat.old, -litter)


####----------- corrections for missing covers -----------####
# join with TTC data
comp2 <- composition %>%
  mutate(blockID = if_else(nchar(blockID) > 1, gsub("[^[:digit:]]", "", blockID), blockID)) %>%
  full_join(my.GR.data, by = c("siteID", "blockID", "turfID", "Treatment", "Year", "species"), suffix = c("", ".new")) %>%
  mutate(cover = coalesce(cover.new, cover),
         recorder = coalesce(recorder.new, recorder),
         totalBryophytes = coalesce(totalBryophytes.new, totalBryophytes),
         vegetationHeight = coalesce(vegetationHeight.new, vegetationHeight),
         mossHeight = coalesce(mossHeight.new, mossHeight)) %>%
  select(-cover.new, -totalBryophytes.new, -vegetationHeight.new, -mossHeight.new, -recorder.new)


# mean of previous and next year
sampling_year <- comp2 %>%
  group_by(turfID) %>%
  distinct(turfID, Year) %>%
  arrange(turfID, Year) %>%
  mutate(sampling = 1:n())

missingCov <- comp2 %>%
  group_by(turfID, species, Treatment) %>%
  filter(!is.na(presence) & is.na(cover)) %>%
  select(siteID, blockID, turfID, Year, species, Treatment)


comp2 %>% group_by(turfID, Treatment) %>%
  filter(is.na(totalGraminoids) & Treatment %in% c("F", "B", "FB", "C")) %>%
  distinct(siteID, blockID, turfID, Year, Treatment, totalGraminoids) %>%
  left_join(sampling_year) %>%
  left_join(
    left_join(filter(comp2, !is.na(totalGraminoids)), sampling_year),
    by = c("turfID"),
    suffix = c("", "_cover")) %>% #join to other years
  distinct(siteID, blockID, turfID, Year, Treatment_cover, Year_cover, Treatment, totalGraminoids, sampling, sampling_cover) %>%
  filter(abs(sampling - sampling_cover) == 1) %>% #next/previous year
  group_by(siteID, blockID, Treatment, turfID, Year) %>%
  filter(n() == 2) %>% #need before and after year
  summarise(totalGraminoids = mean(totalGraminoids), flag = "Subturf w/o cover. Imputed as mean of adjacent years")

missingForbCov <- comp2 %>% group_by(turfID, Treatment) %>%
  filter(is.na(totalForbs) & Treatment %in% c("G", "B", "GB", "C")) %>%
  distinct(siteID, blockID, turfID, Year, Treatment, totalForbs)

missingMossCov <- comp2 %>% group_by(turfID, Treatment) %>%
  filter(is.na(totalBryophytes) & Treatment %in% c("G", "F", "GF", "C")) %>%
  distinct(siteID, blockID, turfID, Year, Treatment, totalBryophytes)

# covers interpolated from cover in year before/after
missingCov <- missingCov %>%
  left_join(sampling_year) %>%
  left_join(
    left_join(filter(comp2, !is.na(cover)), sampling_year),
    by = c("turfID", "species"),
    suffix = c("", "_cover")) %>% #join to other years
  filter(abs(sampling - sampling_cover) == 1) %>% #next/previous year
  group_by(siteID, blockID, Treatment, turfID, species, Year) %>%
  filter(n() == 2) %>% #need before and after year
  summarise(cover = mean(cover), flag = "Subturf w/o cover. Imputed as mean of adjacent years")

misCovSpp <- comp2 %>% filter(!Treatment == "XC") %>%
  filter(is.na(cover) & !is.na(presence)) %>%
  distinct(siteID, blockID, Treatment, turfID, Year, species)

# covers interpolated from site means
misCovSpp2 <- comp2 %>%
  right_join(misCovSpp %>% select(siteID, Year, species)) %>%
  group_by(siteID, species, Year) %>%
  summarise(cover = mean(cover, na.rm = TRUE)) %>%
  filter(!is.na(cover)) %>%
  right_join(misCovSpp)

# adding cover corrections
comp2 <- comp2 %>%
  left_join(missingCov %>% select(-flag), by = c("siteID", "blockID", "Treatment", "turfID", "species", "Year"), suffix = c("", ".new")) %>%
  mutate(cover = coalesce(cover.new, cover)) %>%
  select(-cover.new) %>%
  left_join(misCovSpp2, by = c("siteID", "blockID", "Treatment", "turfID", "species", "Year"), suffix = c("", ".new")) %>%
  mutate(cover = coalesce(cover.new, cover)) %>%
  select(-cover.new, -presence, -turfID.new) %>%
  filter(!is.na(cover))


####----------- compile TTCs from seedclim with FunCaB -----------####
# rejoin funcab attributes of the TTCs in 2016 and 2017
comp2 <- comp2 %>%
  left_join(ttcs1516, by = c("siteID", "blockID", "Treatment", "turfID", "Year", "TTtreat"), suffix = c("", ".new")) %>%
  mutate(mossHeight = coalesce(mossHeight.new, mossHeight),
         vegetationHeight = coalesce(vegetationHeight.new, vegetationHeight),
         totalBryophytes = coalesce(totalBryophytes.new, totalBryophytes),
         totalGraminoids = coalesce(totalGraminoids.new, totalGraminoids),
         totalForbs = coalesce(totalForbs.new, totalForbs)) %>%
  select(-totalBryophytes.new, -vegetationHeight.new, -mossHeight.new, -totalForbs.new, -totalGraminoids.new) %>%
  left_join(ttcs17, by = c("siteID", "blockID", "Treatment", "turfID", "Year", "TTtreat", "recorder", "acro", "pleuro"), suffix = c("", ".new")) %>%
  mutate(mossHeight = coalesce(mossHeight.new, mossHeight),
         vegetationHeight = coalesce(vegetationHeight.new, vegetationHeight),
         totalBryophytes = coalesce(totalBryophytes.new, totalBryophytes),
         totalGraminoids = coalesce(totalGraminoids.new, totalGraminoids),
         totalForbs = coalesce(totalForbs.new, totalForbs)) %>%
  select(-totalBryophytes.new, -vegetationHeight.new, -mossHeight.new, -totalForbs.new, -totalGraminoids.new, -TTtreat)

comp2 <- comp2 %>%
  full_join(FGBs) %>%
  group_by(turfID, Year) %>%
  mutate(acro = case_when(!is.na(pleuro) & is.na(acro) ~ 0,
                          TRUE ~ acro),
         pleuro = case_when(!is.na(acro) & is.na(pleuro) ~ 0,
                          TRUE ~ pleuro),
         totalBryophytes = if_else(is.na(totalBryophytes), pleuro + acro, totalBryophytes)) %>%
  ungroup() %>%
  mutate(turfID = if_else(grepl("TTC", turfID), turfID, substring(turfID, 4, n())),
         Treatment = gsub(" ", "", Treatment),
         turfID = paste0(str_sub(siteID, 1, 3), turfID),
         species = gsub(" ", ".", species),
         blockID = if_else(turfID == "Gud12C", "12", blockID))

# check there are no duplicate species covers
comp2 %>% group_by(turfID, Year, species) %>% summarise(n = n_distinct(cover)) %>% filter(n > 1)
# should be empty


####----------- compute functional group nomenclature -----------####
# functional groups
comp2 <- comp2 %>%
  group_by(turfID, Year, species) %>%
  mutate(cover = case_when(
    turfID == "Alr2XC" & Year == 2016 & species == "Agr.cap" ~ sum(cover),
    TRUE ~ cover
  )) %>%
  left_join(FG) %>%
  mutate(functionalGroup = if_else(
    grepl("pteridophyte", functionalGroup), "forb",
    if_else(grepl("woody", functionalGroup), "forb", functionalGroup)))

# sum of covers
comp2 <- comp2 %>%
  mutate(functionalGroup = if_else(species %in% c("Jun.sp", "Phl.sp", "Luz.tri"), "graminoid",
                                   if_else(species%in% c("Ped.pal", "Pop.tre", "Ste.als", "Ste.sp", "Porub", "Arenaria", "Pilosella"), "forb", functionalGroup))) %>%
  group_by(turfID, Year, functionalGroup) %>%
  mutate(sumcover = sum(cover))

# find turfs where FG covers missed
comp24 <- comp2 %>%
  gather(totalGraminoids, totalForbs, key = totFunctionalGroup, value = totCov) %>%
  group_by(turfID, functionalGroup, Year) %>%
  mutate(totCov = if_else(is.na(totCov), sumcover, totCov)) %>%
  ungroup() %>%
  distinct() %>%
  spread(totFunctionalGroup, totCov)


####----------- clean and correct moss height data -----------####
comp2 <- comp2 %>%
  mutate(mossHeight = case_when(
    turfID == 'Alr3G' & Year == 2017 ~ 8.6,
    turfID == 'Alr5F' & Year == 2017 ~ 17.5,
    turfID == 'Alr5G' & Year == 2017 ~ 17.5,
    turfID == 'Fau2F' & Year == 2017 ~ 4,
    turfID == 'Alr1C' & Year == 2017 ~ 15,
    turfID == 'Ulv2C' & Year == 2017 ~ 0,
    turfID == 'Ovs1C' & Year == 2017 ~ 21, # mean of 2016 and 2018
    TRUE ~ mossHeight),
    vegetationHeight = case_when(
      turfID == 'Ulv3B' & Year == 2017 ~ 44.5,
      turfID == 'Arh2FB' & Year == 2017 ~ 127.5,
      turfID == 'Ovs1C' & Year == 2017 ~ 76.85, # mean of 2016 and 2018
      TRUE ~ vegetationHeight),
    totalBryophytes = case_when(
      turfID == 'Alr1F' & Year == 2015 ~ 0,
      turfID == 'Alr1FGB' & Year == 2015 ~ 0,
      turfID == 'Ovs1C' & Year == 2015 ~ 100,
      turfID == 'Fau2C' & Year == 2015 ~ 40,
      TRUE ~ totalBryophytes),
    totalForbs = case_when(
      turfID == 'Fau2C' & Year == 2015 ~ 65,
      turfID == 'Gud12C' & Year == 2015 ~ 70,
      turfID == 'Vik2C' & Year == 2015 ~ 60,
      TRUE ~ totalForbs),
    totalGraminoids = case_when(
      turfID == 'Gud12C' & Year == 2015 ~ 22,
      turfID == 'Vik2C' & Year == 2015 ~ 30,
      TRUE ~ totalGraminoids))


# fix functional group discrepancies
comp2 <- comp2 %>%
  ungroup() %>%
  rename(forbCov = totalForbs, mossCov = totalBryophytes, graminoidCov = totalGraminoids)

# filter for  moss values from 2017
mossHeight <- comp2 %>%
  filter(Year == 2017) %>%
  select(turfID, mossHeight) %>%
  filter(!(is.na(mossHeight))) %>%
  distinct(turfID, .keep_all = TRUE) %>%
  ungroup()

# remove unwanted columns
comp2 <- comp2 %>%
  select(-acro, -pleuro) %>%
  mutate(graminoidCov = case_when(
    turfID == "Fau1C" & Year == 2017 & species == "Hol.lan" ~ 70,
    turfID == "Fau2C" & Year == 2017 & species == "Hol.lan" ~ 60,
    turfID == "Vik5C" & Year == 2017 & species == "Hol.lan" ~ 45,
    TRUE ~ graminoidCov
  ),
  forbCov = case_when(
    turfID == "Fau1C" & Year == 2017 & species == "Hol.lan" ~ 70,
    turfID == "Fau2C" & Year == 2017 & species == "Hol.lan" ~ 25,
    turfID == "Vik5C" & Year == 2017 & species == "Hol.lan" ~ 60,
    TRUE ~ forbCov)
  )

comp2 <- comp2 %>%
  distinct(siteID, blockID, Treatment, turfID, Year, graminoidCov, forbCov, mossCov, vegetationHeight, mossHeight, litter, cover, species, functionalGroup, sumcover) %>%
  # recode site names
  mutate(siteID = recode(siteID,
                         "Ulvhaugen" = "Ulvehaugen",
                         "Skjellingahaugen" = "Skjelingahaugen",
                         "Ovstedal" = "Ovstedalen"))

# save secondary/derived data
write_csv(comp2, file = "data/community/FunCaB_clean_composition_21-11-03.csv")

