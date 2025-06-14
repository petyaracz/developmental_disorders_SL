# -- setup -- #

setwd('~/Github/developmental_disorders_SL/')

library(tidyverse)
library(patchwork)
library(ggthemes)
library(sjPlot)
library(corrplot)
library(performance)
library(glue)
library(jsonlite)

# -- names -- #

my_labeller = as_labeller(
  c(
    "TD" = 'Typically Developing',
    "DLD" = 'Developmental\nLanguage Disorder',
    "ADHD" = 'Attention-Deficit/\nHyperactivity Disorder',
    "ASD" = 'Autism Spectrum\nDisorder'
  )
)

long_names = c(
    `ID` = "Id",
    # ez nem redundáns a dummy coded diagnózissal? (lehet, hogy nem gond)
    `group` = "Diagnosis",
    `age_years` = "Age in years",
    `expr_vocab` = "Expressive vocabulary",
    `sent_rep` = 'Sentence repetition',
    # ez a prod nem kell, mert AGL offline subscore
    #`prod` = 'Production',
    `IQ` = "Intelligence Quotient",
    `AGL_medRT_diff` = "Artificial Grammar Learning\nmedian RT difference",
    `AGL_offline` = "Artificial Grammar Learning\noffline",
    `digit_span_forward` = "Forward digit span\n(jittered)",
    `digit_span_backward` = "Backward digit span\n(jittered)",
    `PS_vis_RT_med` = "Processing speed\nvisual median RT",
    `PS_ac_RT_med` = "Processing Speed\nacoustic median RT",
    `n_back_2_mean_score` = "N-back 2\nmean score",
    # ez a phr nem kell, mert ez az AGL offlineban benne van
    #`AFC_phr` = "Artificial Grammar Learning\nphrase (jittered)",
    # ez sem kell, mert ez is benne van az AGL offline-ban
    #`AFC_sent` = "Artificial Grammar Learning\nsentence (jittered)",
    `group_TD` = 'Typically developing',
    `group_DLD` = 'Developmental\nLanguage Disorder',
    `group_ADHD` = 'Attention-Deficit/\nHyperactivity Disorder',
    `group_ASD` = 'Autism Spectrum\nDisorder',
    `sent_rep_pred` = "Predicted\nsentence repetition",
    `expr_vocab_pred` = "Predicted\nexpressive vocabulary"
  )
  

# -- fun -- #

# parse json object of xgboost results and parameters into df
parseResults = function(parsed){
  
  # Extract best_params into a data frame
  df_params = data.frame(
    variable = names(parsed$best_params),
    value = unlist(parsed$best_params),
    stringsAsFactors = FALSE
  )
  
  # Add neg_mean_squared_error
  df_params = rbind(
    df_params,
    data.frame(variable = "neg_mean_squared_error", value = parsed$neg_mean_squared_error)
  )
  
  return(df_params)
}

# rename columns using long names
rename_columns = function(dat, mapping) {
  # For each left-hand (old) name in mapping, check if it appears in dat
  # If found, rename that column to the corresponding value
  for (col_name in names(mapping)) {
    if (col_name %in% names(dat)) {
      names(dat)[names(dat) == col_name] = mapping[[col_name]]
    }
  }
  return(dat)
}

# draw raw data w/ sent rep
draw_raw_sr = function(dat,my_var){
  
  my_name = long_names[my_var]
  
  dat |> 
    mutate(group = fct_relevel(group, 'TD')) |> 
    ggplot(aes(!!sym(my_var),sent_rep)) +
    geom_point() +
    # geom_density_2d(colour = 'lightgrey') +
    geom_smooth(method = "gam", formula = y ~ s(x, k = 3)) +
    geom_rug() +
    theme_minimal() +
    facet_wrap( ~ group, nrow = 1, labeller = my_labeller) +
    xlab(my_name) +
    ylab("Sentence repetition") +
    ylim(0,1.3)
}

# draw raw data w/ expr vocab
draw_raw_ev = function(dat,my_var){
  
  my_name = long_names[my_var]
  
  dat |> 
    mutate(group = fct_relevel(group, 'TD')) |> 
    ggplot(aes(!!sym(my_var),expr_vocab)) +
    geom_point() +
    # geom_density_2d(colour = 'lightgrey') +
    geom_smooth(method = "gam", formula = y ~ s(x, k = 3)) +
    geom_rug() +
    theme_minimal() +
    facet_wrap( ~ group, nrow = 1, labeller = my_labeller) +
    xlab(my_name) +
    ylab("Expressive vocabulary") +
    ylim(0.25,1)
}

rename_columns_2 = partial(rename_columns, mapping = long_names)

draw_raw_sr_2 = partial(draw_raw_sr, dat = d)
draw_raw_ev_2 = partial(draw_raw_ev, dat = d)

# -- read -- #

d = read_csv('data/df.csv')
p_ev = read_csv('data/predictions_expr_vocab.csv')
p_sr = read_csv('data/predictions_sent_rep.csv')
f_ev = read_csv('data/feature_importances_expr_vocab.csv')
f_sr = read_csv('data/feature_importances_sent_rep.csv')
x_ev = read_json('data/results_expr_vocab.json')
x_sr = read_json('data/results_sent_rep.json')

# -- wrangle -- #

x_ev = parseResults(x_ev)
x_sr = parseResults(x_sr)

d = d |> 
  left_join(p_ev) |> 
  left_join(p_sr) |> 
  select(-prod,-AFC_phr,-AFC_sent)

# -- corr -- #

# build correlation table of all predictor and outcome variables
cors = d |>
  select(-ID,-age_years,-group,-sent_rep_pred,-expr_vocab_pred) |> 
  rename_columns_2() |> 
  # rename_with(~ str_replace_all(.x, "\\n", " ")) |> # get rid of \n
  na.omit() |> 
  cor() |> 
  as.data.frame() |> 
  rownames_to_column(var = "Var1") %>%
  pivot_longer(cols = -Var1, names_to = "Var2", values_to = "Correlation")

# visualise it
cors |>
  mutate(
    Var1 = fct_inorder(Var1) |> fct_rev(),
    Var2 = Var2 |>
      # str_replace_all('\\n', ' ') |> 
      fct_inorder()
  ) |> 
  ggplot(aes(Var1,Var2,fill = Correlation, label = round(Correlation,2))) +
  geom_tile() +
  geom_text(colour = 'white') +
  theme_few() +
  theme(
    axis.title = element_blank(),
    axis.ticks = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 0),
    plot.margin = margin(5.5, 50, 5.5, 5.5)
    ) +
  guides(fill = 'none') +
  scale_x_discrete(position = 'top') +
  scale_fill_viridis_c(option = 'cividis')

ggsave('viz/correlations.png', width = 9, height = 7, dpi = 900)

# -- missing -- #

d |>
  select(-group,-sent_rep_pred,-expr_vocab_pred) |> 
  rename_columns_2() |> 
  # rename_with(~ str_replace_all(., '\\n', ' ')) |> 
  pivot_longer(-Id) |>
  mutate(
    missing = is.na(value),
    name = fct_inorder(name)
  ) |> 
  ggplot(aes(Id,name,fill = missing)) +
  geom_tile() +
  scale_fill_manual(values = c('black','white')) +
  guides(fill = 'none') +
  theme_few() +
  theme(
    axis.title = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks = element_blank()
        )

ggsave('viz/missing.png', width = 7, height = 5, dpi = 900)

# -- xgboost predictions -- #

p1 = d |> 
  ggplot(aes(sent_rep,sent_rep_pred)) +
  geom_point() +
  geom_smooth() +
  theme_bw() +
  xlab('sentence repetition') +
  ylab('sentence repetition (predicted)')

p2 = d |> 
  ggplot(aes(expr_vocab,expr_vocab_pred)) +
  geom_point() +
  geom_smooth() +
  theme_bw() +
  xlab('expressive vocabulary') +
  ylab('expressive vocabulary (predicted)')

p1 + p2
ggsave('viz/predictions.png', width = 6, height = 3, dpi = 900)

# -- varimp -- #

p1 = f_sr |> 
  mutate(
    Feature = ifelse(Feature %in% names(long_names), long_names[Feature], Feature) |>
      str_replace_all('\\n', ' ') |> 
      fct_reorder(Importance)
    ) |> 
  ggplot(aes(Importance,Feature)) +
  geom_col() +
  theme_few() +
  theme(
    axis.ticks.y = element_blank(),
    axis.title.y = element_blank()
        ) +
  ggtitle('Sentence repetition model')

p2 = f_ev |> 
  mutate(
    Feature = ifelse(Feature %in% names(long_names), long_names[Feature], Feature) |>
      str_replace_all('\\n', ' ') |> 
      fct_reorder(Importance)
  ) |> 
  ggplot(aes(Importance,Feature)) +
  geom_col() +
  theme_few() +
  theme(
    axis.ticks.y = element_blank(),
    axis.title.y = element_blank()
  ) +
  ggtitle('Expressive vocabulary model')

p1 / p2
ggsave('viz/importances.png', dpi = 900, width = 6, height = 6)

# -- raw data -- #

# select interesting variables
sent_rep_varimp = f_sr |> 
  filter(str_detect(Feature, 'group', negate = T)) |> 
  slice(1:5) |> 
  mutate(Feature = fct_reorder(Feature, -Importance)) |> 
  pull(Feature)

expr_vocab_varimp = f_ev |> 
  filter(str_detect(Feature, 'group', negate = T)) |> 
  slice(1:5) |> 
  mutate(Feature = fct_reorder(Feature, -Importance)) |> 
  pull(Feature)

sent_rep_plots = map(levels(sent_rep_varimp), draw_raw_sr_2)
expr_vocab_plots = map(levels(expr_vocab_varimp), draw_raw_ev_2)

wrap_plots(sent_rep_plots, ncol = 1) + plot_annotation(title = 'Sentence repetition and other predictors') + plot_layout(axes = 'collect')
ggsave('viz/sent_rep.png', dpi = 900, width = 6, height = 8)

wrap_plots(expr_vocab_plots, ncol = 1) + plot_annotation(title = 'Expressive vocabulary and other predictors') + plot_layout(axes = 'collect')
ggsave('viz/expr_vocab.png', dpi = 900, width = 6, height = 8)
