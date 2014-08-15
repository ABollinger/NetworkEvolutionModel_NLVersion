extensions [matpowercontingency]

globals [
  total-link-list ;the link list for matpower             
  total-bus-list ;the bus list for matpower               
  total-generator-list ;the generator list for matpower        
  matpower-input-list ;the final input list for matpower (includes the link, bus and generator lists)                   
  matpower-output-list ;the output list from matpower
  origin
  analysis-type
  capacity-of-a-new-110kV-circuit
  capacity-of-a-new-150kV-circuit
  capacity-of-a-new-220kV-circuit
  capacity-of-a-new-380kV-circuit
  capacity-of-a-new-450kV-circuit
  capacity-of-a-new-750kV-circuit
]

breed [grid-operators grid-operator]

breed [generators generator]
breed [distribution-grids distribution-grid]
breed [buses bus]

undirected-link-breed [bus-links bus-link]
undirected-link-breed [transformer-links transformer-link]

grid-operators-own []

generators-own [
  generator-name
  generator-list ;the matpower list for each generator           
  generator-bus
  generator-total-wind-capacity
  generator-distributed-generation-capacity
  generator-x-location
  generator-y-location
  generator-initial-capacity
  generator-temperature-sensitive-capacity
  
  ;matpower variables    
  generator-real-power-output             
  generator-reactive-power-output 
  generator-maximum-reactive-power-output
  generator-minimum-reactive-power-output 
  generator-voltage-magnitude-setpoint 
  generator-mbase
  generator-matpower-status  
  generator-maximum-real-power-output  
  generator-minimum-real-power-output 
  generator-lower-real-power-output  
  generator-upper-real-power-output  
  generator-mimimum-reactive-power-output-at-pc1   
  generator-maximum-reactive-power-output-at-pc1   
  generator-mimimum-reactive-power-output-at-pc2  
  generator-maximum-reactive-power-output-at-pc2 
  generator-ramp-rate-load
  generator-ramp-rate-10-min  
  generator-ramp-rate-30-min 
  generator-ramp-rate-reactive    
  generator-area-participation-factor
  
  ;properties for scenario visualization
  generator-capacity-baseline
  generator-capacity-centralized
  generator-capacity-distributed
  generator-capacity-offshorewind
  generator-capacity-import
]

distribution-grids-own [
  distribution-grid-name
  distribution-grid-peak-demand
  distribution-grid-minimum-demand
  distribution-grid-bus
  distribution-grid-x-location
  distribution-grid-y-location
]

buses-own [
  bus-name
  bus-voltage
  bus-list ;the matpower list for each bus    
  bus-x-location
  bus-y-location
  bus-region
  bus-flood-risk
  sev3-generator-location?
  foreign-bus?
  bus-peak-export-demand
  bus-peak-import-supply
  explored?
  
  ;matpower variables                                          
  bus-number ;matpower variable               
  bus-type-matpower ;matpower variable             
  bus-real-power-demand ;matpower variable
  bus-reactive-power-demand ;matpower variable
  bus-shunt-conductance ;matpower variable
  bus-shunt-susceptance ;matpower variable
  bus-area-number ;matpower variable
  bus-voltage-magnitude ;matpower variable
  bus-voltage-angle ;matpower variable
  bus-base-voltage ;matpower variable
  bus-loss-zone ;matpower variable
  bus-maximum-voltage-magnitude ;matpower variable
  bus-minimum-voltage-magnitude ;matpower variable
]

bus-links-own [
  link-name
  link-circuits
  link-capacity ;the capacity of the link 
  new-link-capacity ;the upgraded capacity of the link
  link-load ;the power flow through a link
  link-voltage
  link-test-contingency?
  link-upgrade-capacity?
  link-list ;the matpower list for each link
  matpower-link-results-list
  
  
  ;matpower variables
  link-from-bus-number
  link-to-bus-number
  link-resistance
  link-reactance
  link-total-line-charging-susceptance
  link-rate-a
  link-rate-b
  link-rate-c
  link-ratio
  link-angle
  link-status-matpower
  link-minimum-angle-difference
  link-maximum-angle-difference
  link-real-power-from
  link-reactive-power-from
  link-real-power-to
  link-reactive-power-to
  
  ;properties for visualization
  link-capacity-baseline
  link-capacity-centralized
  link-capacity-distributed
  link-capacity-offshorewind
  link-capacity-import
  capacity-ratio
]

transformer-links-own [
  transformer-link-name
  transformer-link-list 
  
  ;matpower variables
  transformer-link-from-bus-number 
  transformer-link-to-bus-number 
  transformer-link-resistance 
  transformer-link-reactance 
  transformer-link-total-line-charging-susceptance 
  transformer-link-rate-a 
  transformer-link-rate-b 
  transformer-link-rate-c 
  transformer-link-ratio 
  transformer-link-angle 
  transformer-link-status-matpower 
  transformer-link-minimum-angle-difference 
  transformer-link-maximum-angle-difference
  transformer-link-real-power-from
  transformer-link-reactive-power-from
  transformer-link-real-power-to
  transformer-link-reactive-power-to
]

patches-own []


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; SETUP THE LANDSCAPE ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-and-go
  
  setup-the-landscape
  repeat 40 [grow-transmission-grid]

end
    

to setup-the-landscape
  
  clear-all
  
  format-world
  load-network-data
  verify-network
  
  update-network-visualization
  
  reset-ticks

end


to format-world
  
  resize-world -139 139 -167 167
  set-patch-size 1.85
  ask patches [set pcolor white]
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; LOAD THE NETWORK ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to load-network-data
  
  load-substation-data
  create-foreign-buses
  load-transmission-line-data
  load-transformer-data
  load-distribution-grid-data
  load-generator-data
  set-new-circuit-capacities
  correct-line-capacities
  fill-missing-data

end


to load-substation-data
  
  file-open "inputdata/v10/substations"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    create-buses 1 [
      set bus-voltage item 1 current-line
      set-initial-values-of-bus
      set bus-name item 0 current-line
      set bus-x-location item 2 current-line
      set bus-y-location item 3 current-line
      set bus-region item 4 current-line
      set bus-flood-risk item 6 current-line
    ]
  ]
  file-close
  
  file-open "inputdata/v10/sev3generatorlocations"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask buses with [bus-name = item 1 current-line] [set sev3-generator-location? true]
  ]
  file-close 
  
end


to create-foreign-buses
  
  ask buses with [bus-name = "Zandvliet" or bus-name = "VanEyck" or bus-name = "Diele" or bus-name = "Gronau" or bus-name = "Selfkant" or bus-name = "Feda" or bus-name = "Grain"] [  
    setup-foreign-bus
  ]
  
end


to setup-foreign-bus
  
  ;Net transfer capacities for different countries:
  ;(based on data from http://energieinfo.tennet.org/ on "net transfer capacity" in 2014)
  ;Belgium: 1501
  ;Germany: 2449
  ;Norway: 700
  ;England: 1016
  
  set foreign-bus? true
  if (bus-name = "Zandvliet" or bus-name = "VanEyck") [
    set bus-peak-import-supply 1501 / 2
    set bus-peak-export-demand 1501 / 2
  ]
  if (bus-name = "Diele" or bus-name = "Gronau" or bus-name = "Selfkant" or bus-name = "Wesel") [
    set bus-peak-import-supply 2449 / 3
    set bus-peak-export-demand 2449 / 3
  ]
  if (bus-name = "Feda") [
    set bus-peak-import-supply 700
    set bus-peak-export-demand 700
  ]
  if (bus-name = "Grain") [
    set bus-peak-import-supply 1016
    set bus-peak-export-demand 1016
  ]
  if (bus-name = "Denmark") [
    set bus-peak-import-supply 700
    set bus-peak-export-demand 700
  ]
  
  hatch-generators 1 [
    set-initial-values-of-generator
    set generator-bus myself
    set generator-name [bus-name] of generator-bus
    set generator-x-location [bus-x-location] of generator-bus
    set generator-y-location [bus-y-location] of generator-bus
    setxy generator-x-location generator-y-location
    set generator-maximum-real-power-output 0  
    set generator-temperature-sensitive-capacity 0
  ]
  
  hatch-distribution-grids 1 [
    set distribution-grid-bus myself
    set distribution-grid-name [bus-name] of distribution-grid-bus
    set distribution-grid-x-location [bus-x-location] of distribution-grid-bus
    set distribution-grid-y-location [bus-y-location] of distribution-grid-bus
    setxy distribution-grid-x-location distribution-grid-y-location
    set distribution-grid-peak-demand 0
  ]

end


to load-transmission-line-data
  
  file-open "inputdata/v10/lines"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    let bus1-name (item 0 current-line)
    let bus2-name (item 1 current-line)
    let line-voltage (item 2 current-line)
    let bus1 one-of buses with [bus-name = bus1-name and bus-voltage = line-voltage]
    let bus2 one-of buses with [bus-name = bus2-name and bus-voltage = line-voltage]
    
    ask bus1 [
      create-bus-link-with bus2 [
        set link-voltage item 2 current-line
        set-initial-values-of-link link-voltage
        set link-circuits item 3 current-line
        set link-capacity item 4 current-line * link-circuits
      ]
    ]
  ]
  file-close
  
end

  
to load-transformer-data
  
  file-open "inputdata/v10/transformers"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    let bus1-name (item 0 current-line)
    let bus2-name (item 1 current-line)
    let bus1 one-of buses with [bus-name = bus1-name and bus-voltage = item 2 current-line]
    let bus2 one-of buses with [bus-name = bus2-name and bus-voltage = item 3 current-line]

    ask bus1 [
      create-transformer-link-with bus2 [
        set-initial-values-of-transformer-link
      ]
    ]
  ]
  file-close
  
end
  
  
to load-generator-data
  
  ask buses with [foreign-bus? = false] [
    hatch-generators 1 [
      set-initial-values-of-generator
      set generator-bus myself
      set generator-total-wind-capacity 0
      set generator-distributed-generation-capacity 0
      set generator-name [bus-name] of generator-bus
      set generator-x-location [bus-x-location] of generator-bus
      set generator-y-location [bus-y-location] of generator-bus
      setxy generator-x-location generator-y-location
      set generator-maximum-real-power-output 0
      set generator-temperature-sensitive-capacity 0
    ]
  ]
  
  file-open "inputdata/v10/generators"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask one-of generators with [([bus-name] of generator-bus = item 7 current-line) and ([bus-voltage] of generator-bus = item 8 current-line)] [
      set generator-maximum-real-power-output generator-maximum-real-power-output + item 5 current-line
      if (item 6 current-line = "Wind") [set generator-total-wind-capacity generator-total-wind-capacity + item 5 current-line]
      set generator-temperature-sensitive-capacity generator-temperature-sensitive-capacity + item 5 current-line * item 9 current-line
    ]
  ]
  file-close
  
  ;2010 local generation in distribution grids = 6220 MW (taken from Tennet 2010/2016 KCP, part IIA, pg. 16, English version)
  let distributed-generation-per-distribution-grid 6220 / count distribution-grids with [[foreign-bus?] of distribution-grid-bus = false]
  ask distribution-grids with [[foreign-bus?] of distribution-grid-bus = false] [
    ask one-of generators with [generator-bus = [distribution-grid-bus] of myself] [
      set generator-maximum-real-power-output generator-maximum-real-power-output + distributed-generation-per-distribution-grid
      set generator-distributed-generation-capacity generator-distributed-generation-capacity + distributed-generation-per-distribution-grid
    ]
  ]
  
  ask generators [set generator-initial-capacity generator-maximum-real-power-output]
  
end
  
  
to load-distribution-grid-data
  
  file-open "inputdata/v10/distributiongrids"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    create-distribution-grids 1 [
      set distribution-grid-name item 0 current-line
      set distribution-grid-bus one-of buses with [bus-name = item 1 current-line and bus-voltage = item 3 current-line]
      set distribution-grid-x-location [bus-x-location] of distribution-grid-bus
      set distribution-grid-y-location [bus-y-location] of distribution-grid-bus
      setxy distribution-grid-x-location distribution-grid-y-location
      set distribution-grid-peak-demand item 5 current-line
    ]
  ]
  file-close
  
  let total-peak-demand-non-simultaneous sum [distribution-grid-peak-demand] of distribution-grids
  let total-peak-demand-simultaneous 17645 ;number taken from Tennet 2010/2016 KCP, part IIA, pg. 16, English version
  let peak-demand-factor total-peak-demand-simultaneous / total-peak-demand-non-simultaneous
  ask distribution-grids with [[foreign-bus?] of distribution-grid-bus = false] [
    set distribution-grid-peak-demand distribution-grid-peak-demand * peak-demand-factor
  ]
  
end


to fill-missing-data
  
  ask bus-links [
    if (link-circuits = 0) [set link-circuits 2] ;ASSUMPTION: if we don't know the number of circuits a line has, we set it to 2
  ]
  
  ;fill in the missing capacities
  fill-missing-capacities-using-mean-values
  
end


to correct-line-capacities
  
  ;power factor correction
  let power-factor 0.98 ;ASSUMPTION: assumed value of power factor
  ask bus-links with [link-voltage != 450] [set link-capacity link-capacity * power-factor]
  
end


to fill-missing-capacities-using-mean-values
  
  ask bus-links with [link-capacity = 0 and link-voltage = 110] [
    set link-capacity mean [link-capacity] of bus-links with [link-voltage = 110 and link-capacity != 0]
    if (print-stuff?) [print (word "Upgrading capacity of " link-name " from " 0 " to " link-capacity ".")]  
  ]
  ask bus-links with [link-capacity = 0 and link-voltage = 150] [
    set link-capacity mean [link-capacity] of bus-links with [link-voltage = 150 and link-capacity != 0]
    if (print-stuff?) [print (word "Upgrading capacity of " link-name " from " 0 " to " link-capacity ".")]  
  ]
  ask bus-links with [link-capacity = 0 and link-voltage = 220] [
    set link-capacity mean [link-capacity] of bus-links with [link-voltage = 220 and link-capacity != 0]
    if (print-stuff?) [print (word "Upgrading capacity of " link-name " from " 0 " to " link-capacity ".")]  
  ]
  ask bus-links with [link-capacity = 0 and link-voltage = 380] [
    set link-capacity mean [link-capacity] of bus-links with [link-voltage = 380 and link-capacity != 0]
    if (print-stuff?) [print (word "Upgrading capacity of " link-name " from " 0 " to " link-capacity ".")]  
  ]
  
end


to set-new-circuit-capacities
  
  set capacity-of-a-new-110kV-circuit max [link-capacity / link-circuits] of bus-links with [link-voltage = 110 and link-circuits != 0]
  set capacity-of-a-new-150kV-circuit max [link-capacity / link-circuits] of bus-links with [link-voltage = 150 and link-circuits != 0]
  set capacity-of-a-new-220kV-circuit max [link-capacity / link-circuits] of bus-links with [link-voltage = 220 and link-circuits != 0]
  set capacity-of-a-new-380kV-circuit max [link-capacity / link-circuits] of bus-links with [link-voltage = 380 and link-circuits != 0]
  set capacity-of-a-new-450kV-circuit max [link-capacity / link-circuits] of bus-links with [link-voltage = 450 and link-circuits != 0]
  set capacity-of-a-new-750kV-circuit max [link-capacity / link-circuits] of bus-links with [link-voltage = 380 and link-circuits != 0]
  
  if (print-stuff?) [
    print ""
    print "Calculated new circuit capacities for the different voltage levels:"
    print (word "110kV: "capacity-of-a-new-110kV-circuit)
    print (word "150kV: "capacity-of-a-new-150kV-circuit)
    print (word "220kV: "capacity-of-a-new-220kV-circuit)
    print (word "380kV: "capacity-of-a-new-380kV-circuit)
    print (word "450kV: "capacity-of-a-new-450kV-circuit)
    print (word "750kV: "capacity-of-a-new-750kV-circuit)
  ]
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; EVOLVE THE INFRASTRUCTURE ;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to grow-transmission-grid
  
  if (print-stuff?) [
    print ""
    print (word "***** TICK " ticks " *****")
  ]
  
  if (scenario != "baseline scenario") [
    update-generation-capacity-and-peak-demand
    
    if (update-line-capacities?) [update-line-capacities]
    if (construct-new-lines?) [add-predefined-lines]

    update-network-visualization
  
    if (log-link-loads?) [log-link-load]
    if (ticks = 40) [
      if (log-network?) [log-network]
    ]
  ]
  
  if (scenario = "baseline scenario") [
    if (log-network?) [log-network]
    stop
  ]
  
  tick
  
end


to update-generation-capacity-and-peak-demand
  
  let demand-change 0
  let capacity-reduction-due-to-sev3-shift 0
    
  ;adjust the capacity of centralized generators due to the shift to sev3 locations
  ask generators with [[sev3-generator-location?] of generator-bus = false and 
    [foreign-bus?] of generator-bus = false and 
    generator-distributed-generation-capacity <= generator-maximum-real-power-output] [
    
    let capacity-to-subtract generator-initial-capacity * 0.05 ;subtract 5% of capacity ever year
    ifelse (generator-maximum-real-power-output - generator-distributed-generation-capacity - capacity-to-subtract > 0) [
      let temperature-sensitive-capacity-ratio generator-temperature-sensitive-capacity / generator-maximum-real-power-output
      set generator-maximum-real-power-output generator-maximum-real-power-output - capacity-to-subtract
      set generator-temperature-sensitive-capacity generator-temperature-sensitive-capacity - capacity-to-subtract * temperature-sensitive-capacity-ratio
      set capacity-reduction-due-to-sev3-shift capacity-reduction-due-to-sev3-shift + capacity-to-subtract
    ]
    [
      set capacity-reduction-due-to-sev3-shift capacity-reduction-due-to-sev3-shift + generator-maximum-real-power-output - generator-distributed-generation-capacity
      set generator-maximum-real-power-output generator-distributed-generation-capacity
      set generator-temperature-sensitive-capacity 0
    ]
  ]
    
  ;adjust the demand of distribution grids
  let total-initial-demand sum [distribution-grid-peak-demand] of distribution-grids with [[foreign-bus?] of distribution-grid-bus = false]    
  ask distribution-grids with [[foreign-bus?] of distribution-grid-bus = false] [
    set distribution-grid-peak-demand distribution-grid-peak-demand * (1 + rate-of-demand-growth / 100)
  ]
  let total-new-demand sum [distribution-grid-peak-demand] of distribution-grids with [[foreign-bus?] of distribution-grid-bus = false]
  set demand-change total-new-demand - total-initial-demand
  
  if (scenario = "centralized generation scenario") [
    
    ;increase domestic generation capacity by the amount which demand increased plus the capacity reduction due to the sev3 shift
    let total-generation-capacity sum [generator-maximum-real-power-output] of generators with [[sev3-generator-location?] of generator-bus = true]
    ask generators with [[sev3-generator-location?] of generator-bus = true and generator-maximum-real-power-output > 0] [
      let amount-to-add (demand-change + capacity-reduction-due-to-sev3-shift) * generator-maximum-real-power-output / total-generation-capacity 
      let temperature-sensitive-capacity-ratio generator-temperature-sensitive-capacity / generator-maximum-real-power-output
      set generator-maximum-real-power-output generator-maximum-real-power-output + amount-to-add
      set generator-temperature-sensitive-capacity generator-maximum-real-power-output * temperature-sensitive-capacity-ratio
    ]
  ]
  
  if (scenario = "distributed generation scenario") [
    
    ;increase the capacity of generators attached to the same buses as distribution grids
    let total-new-distributed-generation-capacity 0
    ask distribution-grids with [[foreign-bus?] of distribution-grid-bus = false] [
      ask distribution-grid-bus [
        ask generators with [generator-bus = myself] [
          let amount-to-add (demand-change + capacity-reduction-due-to-sev3-shift) / (count distribution-grids with [[foreign-bus?] of distribution-grid-bus = false])
          ;let amount-to-add ((42000 - 8000) / 40) / (count distribution-grids with [[foreign-bus?] of distribution-grid-bus = false])
          set generator-maximum-real-power-output generator-maximum-real-power-output + amount-to-add
          set generator-distributed-generation-capacity generator-distributed-generation-capacity + amount-to-add
          ;set total-new-distributed-generation-capacity total-new-distributed-generation-capacity + amount-to-add
        ]
      ]
    ]
  ]

  if (scenario = "offshore wind scenario") [
    
    ;increase the capacity of offshore wind generators
    ask generators with [
        ([bus-name] of generator-bus = "Eemshaven" or 
        [bus-name] of generator-bus = "Beverwijk" or 
        [bus-name] of generator-bus = "Maasvlakte" or 
        [bus-name] of generator-bus = "Borssele") and ([bus-voltage] of generator-bus = 380)] [
      let amount-to-add (demand-change + capacity-reduction-due-to-sev3-shift) / 4
      ;let amount-to-add (24000 / 40) / 4 ;Vision2030 suggests that 6000MW of offshore wind capacity is possible by 2020 - at this rate there will be 24000MW of capacity by 2050
      set generator-maximum-real-power-output generator-maximum-real-power-output + amount-to-add
      set generator-total-wind-capacity generator-total-wind-capacity + amount-to-add
    ]
  ]
  
  if (scenario = "import scenario") [
    
    let domestic-generation-reduction 0
    ask generators with [[foreign-bus?] of generator-bus = false] [
      set generator-maximum-real-power-output generator-maximum-real-power-output - 0.01 * generator-maximum-real-power-output
      set domestic-generation-reduction domestic-generation-reduction + 0.01 * generator-maximum-real-power-output
    ]
    
    ask buses with [foreign-bus? = true] [
      set bus-peak-import-supply bus-peak-import-supply + ((demand-change + domestic-generation-reduction) / (count buses with [foreign-bus? = true]))
    ]
  ]
  
  if (scenario = "export scenario") [
    
    let original-export-demand sum [bus-peak-export-demand] of buses with [foreign-bus? = true]
    ask buses with [foreign-bus? = true] [
      set bus-peak-export-demand bus-peak-export-demand * 1.01
    ]
    let growth-in-export-demand-this-tick sum [bus-peak-export-demand] of buses with [foreign-bus? = true] - original-export-demand
    
    ;increase domestic generation capacity by the amount which demand increased plus the capacity reduction due to the sev3 shift plus increased export demand
    let total-generation-capacity sum [generator-maximum-real-power-output] of generators with [[sev3-generator-location?] of generator-bus = true]
    ask generators with [[sev3-generator-location?] of generator-bus = true and generator-maximum-real-power-output > 0] [
      let amount-to-add (demand-change + capacity-reduction-due-to-sev3-shift + growth-in-export-demand-this-tick) * generator-maximum-real-power-output / total-generation-capacity 
      let temperature-sensitive-capacity-ratio generator-temperature-sensitive-capacity / generator-maximum-real-power-output
      set generator-maximum-real-power-output generator-maximum-real-power-output + amount-to-add
      set generator-temperature-sensitive-capacity generator-maximum-real-power-output * temperature-sensitive-capacity-ratio
    ]
    
  ]

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;; UPDATE LINE CAPACITIES ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;ASSUMPTION: We ignore the possibility of lines being removed, even though this sometimes happens according to Tennet.
;ASSUMPTION: A differentiation b/t AC and DC cables is not included.
;ASSUMPTION: Reactive power flows are ignored.
;ASSUMPTION: The 100MW exception is ignored.

to update-line-capacities
  
  ;let scenarios ["ExportBasic"]
  let scenarios ["ExportBasic" "ExportNorth" "ExportWest" "ExportSouthwest" "ExportWind" "Import" "SubgridNorth" "SubgridSouth" "SubgridWest" "SubgridEast" "SubgridRandmeren"] 
  foreach scenarios [
  
    if (print-stuff?) [
      print ""
      print (word "Testing scenario " ?)
    ]
  
    if (? = "ExportBasic" or ? = "ExportNorth" or ? = "ExportWest" or ? = "ExportSouthwest" or ? = "Import") [
      set-supply-and-demand-for-EHV-scenarios ?
    ]
  
    if (? = "SubgridNorth" or ? = "SubgridSouth" or ? = "SubgridWest" or ? = "SubgridEast" or ? = "SubgridRandmeren") [
      set-supply-and-demand-for-HV-scenarios ?
    ]
    
    ;perform contingency analyis
    set-power-demand-of-buses
    create-matpower-lists
    run-matpower
    
    set-line-capacities
  ]

end


to set-supply-and-demand-for-EHV-scenarios [current-scenario]
  
  ask generators [set generator-real-power-output 0]
  
  ;SET THE ANALYSIS TYPE
  set analysis-type EHV-contingency-type
  
  ;SET THE LINKS TO BE TESTED IN THE CONTINGENCY ANALYSIS
  ;ASSUMPTION: ExportMaasvlakte scenario has been changed to ExportWest scenario, which also includes production in the rest of the west
  if (current-scenario = "ExportBasic" or current-scenario = "ExportNorth" or current-scenario = "ExportWest" or current-scenario = "ExportSouthwest" or current-scenario = "ExportWind" or current-scenario = "Import") [
    ask bus-links with [link-voltage = 450 or link-voltage = 380 or link-voltage = 220] [set link-test-contingency? 1]
    ask bus-links with [link-voltage = 150 or link-voltage = 110] [set link-test-contingency? 0]
  ]
  
  ;SET THE IMPORTS AND EXPORTS
  if (current-scenario = "ExportBasic" or current-scenario = "ExportNorth" or current-scenario = "ExportWest" or current-scenario = "ExportWind" or current-scenario = "ExportSouthwest") [
    ask buses with [bus-region = "Germany" or bus-region = "Belgium"] [
      ask generators with [generator-bus = myself] [set generator-real-power-output 0]
      ask distribution-grids with [distribution-grid-bus = myself] [set distribution-grid-peak-demand [bus-peak-export-demand] of myself]
    ]
  ]
  
  if (current-scenario = "Import") [
    ask buses with [bus-region = "Germany" or bus-region = "Belgium"] [
      ask generators with [generator-bus = myself] [set generator-real-power-output [bus-peak-import-supply] of myself]
      ask distribution-grids with [distribution-grid-bus = myself] [set distribution-grid-peak-demand 0]
    ]
  ]
  
  if (current-scenario = "ExportBasic" or current-scenario = "ExportNorth" or current-scenario = "ExportSouthwest" or current-scenario = "Import" ) [
    ask buses with [bus-region = "Norway"] [
      ask generators with [generator-bus = myself] [set generator-real-power-output [bus-peak-import-supply] of myself]
      ask distribution-grids with [distribution-grid-bus = myself] [set distribution-grid-peak-demand 0]
    ]
    ask buses with [bus-region = "England"] [
      ask generators with [generator-bus = myself] [set generator-real-power-output 0]
      ask distribution-grids with [distribution-grid-bus = myself] [set distribution-grid-peak-demand [bus-peak-export-demand] of myself]
    ]
  ]
  
  if (current-scenario = "ExportWest" ) [
    ask buses with [bus-region = "Norway" or bus-region = "England"] [
      ask generators with [generator-bus = myself] [set generator-real-power-output [bus-peak-import-supply] of myself]
      ask distribution-grids with [distribution-grid-bus = myself] [set distribution-grid-peak-demand 0]
    ]
  ]
  
  if (current-scenario = "ExportWind" ) [
    ask buses with [bus-region = "Norway" or bus-region = "England"] [
      ask generators with [generator-bus = myself] [set generator-real-power-output 0]
      ask distribution-grids with [distribution-grid-bus = myself] [set distribution-grid-peak-demand [bus-peak-export-demand] of myself]
    ]
  ]
  
  ;SET THE GENERATOR OUTPUTS
  let total-demand sum [distribution-grid-peak-demand] of distribution-grids
  let total-supply sum [generator-maximum-real-power-output] of generators
  let remaining-demand total-demand - sum [generator-real-power-output] of generators
  
  if (current-scenario = "ExportBasic" or current-scenario = "Import") [
    let total-domestic-supply sum [generator-maximum-real-power-output] of generators with [[foreign-bus?] of generator-bus = false]
    ask generators with [[foreign-bus?] of generator-bus = false] [
      set generator-real-power-output generator-maximum-real-power-output * remaining-demand / total-domestic-supply
    ]
  ]
  
  if (current-scenario = "ExportNorth") [
    let total-regional-supply sum [generator-maximum-real-power-output] of generators with [[bus-region] of generator-bus = "North"]
    ask generators with [[bus-region] of generator-bus = "North"] [
      ifelse (total-regional-supply <= remaining-demand) [set generator-real-power-output generator-maximum-real-power-output]
      [set generator-real-power-output generator-maximum-real-power-output * remaining-demand / total-regional-supply]
    ]
    set remaining-demand total-demand - sum [generator-real-power-output] of generators
    let total-supply-outside-region sum [generator-maximum-real-power-output] of generators with [[bus-region] of generator-bus != "North"]
    ask generators with [[bus-region] of generator-bus != "North"] [
      set generator-real-power-output generator-maximum-real-power-output * remaining-demand / total-supply-outside-region
    ]
  ]
  
  if (current-scenario = "ExportWest") [
    let total-regional-supply sum [generator-maximum-real-power-output] of generators with [[bus-region] of generator-bus = "West"]
    ask generators with [[bus-region] of generator-bus = "West"] [
      ifelse (total-regional-supply <= remaining-demand) [set generator-real-power-output generator-maximum-real-power-output]
      [set generator-real-power-output generator-maximum-real-power-output * remaining-demand / total-regional-supply]
    ]
    set remaining-demand total-demand - sum [generator-real-power-output] of generators
    let total-supply-outside-region sum [generator-maximum-real-power-output] of generators with [[bus-region] of generator-bus != "West"]
    ask generators with [[bus-region] of generator-bus != "West"] [
      set generator-real-power-output generator-maximum-real-power-output * remaining-demand / total-supply-outside-region
    ]
  ]
  
  if (current-scenario = "ExportSouthwest") [
    let total-regional-supply sum [generator-maximum-real-power-output] of generators with [[bus-region] of generator-bus = "West" or [bus-region] of generator-bus = "South"]
    ask generators with [[bus-region] of generator-bus = "West" or [bus-region] of generator-bus = "South"] [
      ifelse (total-regional-supply <= remaining-demand) [set generator-real-power-output generator-maximum-real-power-output]
      [set generator-real-power-output generator-maximum-real-power-output * remaining-demand / total-regional-supply]
    ]
    set remaining-demand total-demand - sum [generator-real-power-output] of generators
    let total-supply-outside-region sum [generator-maximum-real-power-output] of generators with [[bus-region] of generator-bus != "West" and [bus-region] of generator-bus != "South"]
    ask generators with [[bus-region] of generator-bus != "West" and [bus-region] of generator-bus != "South"] [
      set generator-real-power-output generator-maximum-real-power-output * remaining-demand / total-supply-outside-region
    ]
  ]

  if (current-scenario = "ExportWind") [
    let total-regional-supply sum [generator-total-wind-capacity] of generators
    ask generators [
      ifelse (total-regional-supply <= remaining-demand) [set generator-real-power-output generator-total-wind-capacity]
      [set generator-real-power-output generator-total-wind-capacity * remaining-demand / total-regional-supply]
    ]
    set remaining-demand total-demand - sum [generator-real-power-output] of generators
    let total-supply-outside-region sum [generator-maximum-real-power-output - generator-total-wind-capacity] of generators
    ask generators [
      set generator-real-power-output generator-real-power-output + (generator-maximum-real-power-output - generator-total-wind-capacity) * remaining-demand / total-supply-outside-region
    ]
  ]
  
end


to set-supply-and-demand-for-HV-scenarios [current-scenario]
  
  ;ASSUMPTION: The settings for the subgrid scenarios are equivalent to the "ExportBasic" scenario, except that only contingencies within the subgrid are tested.
  ; This is a simplification of Tennet's procedure which also has specific settings for the deployment of CHP and wind within the subgrids.
  ;ASSUMPTION: The subgrids are tested for n-1 at peak, rather than n-1 during maintenance. 
  
  ask generators [set generator-real-power-output 0]
  
  ;SET THE ANALYSIS TYPE
  set analysis-type HV-contingency-type
  
  ;SET THE LINKS TO BE TESTED IN THE CONTINGENCY ANALYSIS
  ask bus-links [set link-test-contingency? 0]
  
  if (current-scenario = "SubgridNorth") [
    ask bus-links with [(link-voltage = 150 or link-voltage = 110) and ([bus-region] of end1 = "North" or [bus-region] of end2 = "North")] [set link-test-contingency? 1]
  ]
  
  if (current-scenario = "SubgridSouth") [
    ask bus-links with [(link-voltage = 150 or link-voltage = 110) and ([bus-region] of end1 = "South" or [bus-region] of end2 = "South")] [set link-test-contingency? 1]
  ]
  
  if (current-scenario = "SubgridWest") [
    ask bus-links with [(link-voltage = 150 or link-voltage = 110) and ([bus-region] of end1 = "West" or [bus-region] of end2 = "West")] [set link-test-contingency? 1]
  ]
  
  if (current-scenario = "SubgridEast") [
    ask bus-links with [(link-voltage = 150 or link-voltage = 110) and ([bus-region] of end1 = "East" or [bus-region] of end2 = "East")] [set link-test-contingency? 1]
  ]
  
  if (current-scenario = "SubgridRandmeren") [
    ask bus-links with [(link-voltage = 150 or link-voltage = 110) and ([bus-region] of end1 = "Randmeren" or [bus-region] of end2 = "Randmeren")] [set link-test-contingency? 1]
  ]

  ;SET THE IMPORTS AND EXPORTS
  ask buses with [bus-region = "Germany" or bus-region = "Belgium" or bus-region = "England"] [
    ask generators with [generator-bus = myself] [set generator-real-power-output 0]
    ask distribution-grids with [distribution-grid-bus = myself] [set distribution-grid-peak-demand [bus-peak-export-demand] of myself]
  ]
  
  ask buses with [bus-region = "Norway"] [
    ask generators with [generator-bus = myself] [set generator-real-power-output [bus-peak-import-supply] of myself]
    ask distribution-grids with [distribution-grid-bus = myself] [set distribution-grid-peak-demand 0]
  ]
  
  ;SET THE GENERATOR OUTPUTS
  let total-demand sum [distribution-grid-peak-demand] of distribution-grids
  ;let total-supply sum [generator-maximum-real-power-output] of generators
  let remaining-demand total-demand - sum [generator-real-power-output] of generators
  
  let total-domestic-supply sum [generator-maximum-real-power-output] of generators with [[foreign-bus?] of generator-bus = false]
  ask generators with [[foreign-bus?] of generator-bus = false] [
    set generator-real-power-output generator-maximum-real-power-output * remaining-demand / total-domestic-supply
  ]
  
end


to set-power-demand-of-buses
  
  ask buses [
    set bus-real-power-demand sum [distribution-grid-peak-demand] of distribution-grids with [distribution-grid-bus = myself]
  ]
  
end


to create-matpower-lists
  
  ask buses [
    set bus-list 
      (list 
        bus-number 
        bus-type-matpower 
        bus-real-power-demand 
        bus-reactive-power-demand 
        bus-shunt-conductance 
        bus-shunt-susceptance 
        bus-area-number 
        bus-voltage-magnitude 
        bus-voltage-angle 
        bus-base-voltage 
        bus-loss-zone 
        bus-maximum-voltage-magnitude 
        bus-minimum-voltage-magnitude)
  ]
  
  ask generators [
    set generator-list 
        (list 
          [bus-number] of generator-bus
          generator-real-power-output 
          generator-reactive-power-output 
          generator-maximum-reactive-power-output 
          generator-minimum-reactive-power-output 
          generator-voltage-magnitude-setpoint 
          generator-mbase 
          generator-matpower-status 
          generator-maximum-real-power-output 
          generator-minimum-real-power-output 
          generator-lower-real-power-output 
          generator-upper-real-power-output 
          generator-mimimum-reactive-power-output-at-pc1 
          generator-maximum-reactive-power-output-at-pc1 
          generator-mimimum-reactive-power-output-at-pc2 
          generator-maximum-reactive-power-output-at-pc2 
          generator-ramp-rate-load 
          generator-ramp-rate-10-min 
          generator-ramp-rate-30-min 
          generator-ramp-rate-reactive 
          generator-area-participation-factor) 
  ]
  
  ask bus-links [
    set link-list 
      (list 
        link-from-bus-number 
        link-to-bus-number 
        link-resistance 
        link-reactance 
        link-total-line-charging-susceptance 
        link-rate-a 
        link-rate-b 
        link-rate-c 
        link-ratio 
        link-angle 
        link-status-matpower
        link-minimum-angle-difference 
        link-maximum-angle-difference)
      
      set link-list lput link-circuits link-list
      set link-list lput link-voltage link-list
      set link-list lput link-test-contingency? link-list
  ]
  
  ask transformer-links [
    set transformer-link-list 
      (list 
        transformer-link-from-bus-number 
        transformer-link-to-bus-number 
        transformer-link-resistance 
        transformer-link-reactance 
        transformer-link-total-line-charging-susceptance 
        transformer-link-rate-a 
        transformer-link-rate-b 
        transformer-link-rate-c 
        transformer-link-ratio 
        transformer-link-angle 
        transformer-link-status-matpower
        transformer-link-minimum-angle-difference 
        transformer-link-maximum-angle-difference)
      
      set transformer-link-list lput 1 transformer-link-list
      set transformer-link-list lput 0 transformer-link-list
      set transformer-link-list lput 0 transformer-link-list
  ]
  
end


to run-matpower
  
  ;create the bus list for matpower
  let matpower-total-bus-list [] ;create an empty total bus list
  ask buses [set matpower-total-bus-list lput bus-list matpower-total-bus-list] ;add each bus list to the total bus list
  set matpower-total-bus-list sort-by [first ?1 < first ?2] matpower-total-bus-list ;sort the total bus list by bus number. this is necessary; otherwise matpower sometimes fails
  
  ;create the gen list and gencost list for matpower
  let matpower-total-generator-list [] ;create an empty total generator list
  ask generators [set matpower-total-generator-list lput generator-list matpower-total-generator-list] ;add each generator list to the total generator list
  
  ;create the link list for matpower
  let matpower-total-link-list [] ;create an empty total link list
  let capacity-list []
  ask bus-links [
    set matpower-total-link-list lput link-list matpower-total-link-list ;for each link, add the link list to the total link list
    let link-capacity-list [] 
    set link-capacity-list lput link-from-bus-number link-capacity-list
    set link-capacity-list lput link-to-bus-number link-capacity-list
    set link-capacity-list lput link-capacity link-capacity-list
    set capacity-list lput link-capacity-list capacity-list
  ]
  ask transformer-links [
    set matpower-total-link-list lput transformer-link-list matpower-total-link-list ;for each transformer link, add the link list to the total link list
    let link-capacity-list [] 
    set link-capacity-list lput transformer-link-from-bus-number link-capacity-list
    set link-capacity-list lput transformer-link-to-bus-number link-capacity-list
    set link-capacity-list lput 0 link-capacity-list
    set capacity-list lput link-capacity-list capacity-list
  ]
  
  ;set the extra variables for matpower
  let basemva 100
  let area [1 1]
  
  ;assemble the final list to be inputted to matpower
  set matpower-input-list (list basemva matpower-total-bus-list matpower-total-generator-list matpower-total-link-list area analysis-type) 
  if (print-matpower-data?) [print matpower-input-list]
  
  ;pass the input list to matpower
  set matpower-output-list matpowercontingency:octavetest matpower-input-list
  if (print-matpower-data?) [print matpower-output-list]
  
end


to set-line-capacities
  
  let matpower-link-output-data item 0 matpower-output-list
  ask bus-links [
    
    set link-load 0
    set matpower-link-results-list []
    
    foreach matpower-link-output-data [
      if (item 0 ? = link-from-bus-number AND item 1 ? = link-to-bus-number) [set matpower-link-results-list ?] ;if the numbers of the from bus and the to bus match, extract the data for this link
    ]
    
    if (matpower-link-results-list != []) [
      set link-load item 4 matpower-link-results-list * link-circuits
    ]
  ]
  
  ;upgrade the capacity of only those lines which are included in the current scenario
  ask bus-links [
    ifelse (link-test-contingency? = 1) [set link-upgrade-capacity? true] [set link-upgrade-capacity? false]
  ]
  
  let EHV-lines-upgraded 0
  let HV-lines-upgraded 0
  
  ask bus-links with [link-upgrade-capacity? = true] [
    if (link-capacity * 1.1 < link-load) [
      set new-link-capacity link-capacity
      while [new-link-capacity * 1.1 < link-load] [
        if (link-voltage = 110) [set new-link-capacity new-link-capacity + link-capacity / link-circuits] 
        if (link-voltage = 150) [set new-link-capacity new-link-capacity + link-capacity / link-circuits] 
        if (link-voltage = 220) [set new-link-capacity new-link-capacity + link-capacity / link-circuits] 
        if (link-voltage = 380) [set new-link-capacity new-link-capacity + link-capacity / link-circuits]
        if (link-voltage = 450) [set new-link-capacity new-link-capacity + link-capacity / link-circuits]
        if (link-voltage = 750) [set new-link-capacity new-link-capacity + link-capacity / link-circuits]
        set link-circuits link-circuits + 1 
      ]
      if (print-stuff?) [print (word "Upgrading capacity of " link-name " from " link-capacity " to " new-link-capacity ". Link load is " link-load)]  
      set link-capacity new-link-capacity
      if (link-voltage <= 150) [set HV-lines-upgraded HV-lines-upgraded + 1]
      if (link-voltage > 150) [set EHV-lines-upgraded EHV-lines-upgraded + 1]
    ]
  ]
  
  if (print-stuff?) [
    print (word "Upgraded capacity of " EHV-lines-upgraded " EHV lines.")
    print (word "Upgraded capacity of " HV-lines-upgraded " HV lines.")
  ]
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; ADD NEW PREDEFINED LINES ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to add-predefined-lines
  
  add-new-substations
  add-new-lines
  add-new-transformers
  
end


to add-new-substations
  
  file-open "inputdata/v10/newsubstations"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    if (item 7 current-line = ticks + 2010) [
      create-buses 1 [
        set bus-voltage item 1 current-line
        set-initial-values-of-bus
        set bus-name item 0 current-line
        set bus-x-location item 2 current-line
        set bus-y-location item 3 current-line
        set bus-region item 4 current-line
        set bus-flood-risk item 5 current-line
        set foreign-bus? false
        
        if (print-stuff?) [
          print ""
          print (word "CREATED NEW SUBSTATION: " bus-name)
        ]
      ]
    ]
  ]
  file-close
  
end


to add-new-lines
  
  file-open "inputdata/v10/newlines"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    if (item 6 current-line = ticks + 2010) [
      let bus1-name (item 0 current-line)
      let bus2-name (item 1 current-line)
      let line-voltage (item 2 current-line)
      let bus1 one-of buses with [bus-name = bus1-name and bus-voltage = line-voltage]
      let bus2 one-of buses with [bus-name = bus2-name and bus-voltage = line-voltage]
      
      ask bus1 [
        create-bus-link-with bus2 [
          set link-voltage item 2 current-line
          set-initial-values-of-link link-voltage
          set link-circuits item 3 current-line
          set link-capacity item 4 current-line * link-circuits
          
          if (print-stuff?) [
            print ""
            print (word "CREATED NEW LINE: " link-name)
          ]
          
          ;power factor correction
          let power-factor 0.98 ;ASSUMPTION: assumed value of power factor
          if (link-voltage != 450) [set link-capacity link-capacity * power-factor]
        ]
      ]
    ]
  ]
  file-close
  
  fill-missing-data
  
  ask buses with [foreign-bus? = false and (bus-name = "Denmark" or bus-name = "Wesel")] [setup-foreign-bus]
  
end


to add-new-transformers
  
  file-open "inputdata/v10/newtransformers"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    if (item 5 current-line = ticks + 2010) [
      let bus1-name (item 0 current-line)
      let bus2-name (item 1 current-line)
      let bus1 one-of buses with [bus-name = bus1-name and bus-voltage = item 2 current-line]
      let bus2 one-of buses with [bus-name = bus2-name and bus-voltage = item 3 current-line]
      
      ask bus1 [
        create-transformer-link-with bus2 [
          set-initial-values-of-transformer-link
          
          if (print-stuff?) [
            print ""
            print (word "CREATED NEW TRANSFORMER: " transformer-link-name)
          ]
        ]
      ]
    ]
  ]
  file-close
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;; SET INITIAL COMPONENT VALUES ;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to set-initial-values-of-generator
  
  ;matpower variables
  set generator-bus nobody
  set generator-real-power-output 0
  set generator-reactive-power-output 0
  set generator-maximum-reactive-power-output 0
  set generator-minimum-reactive-power-output 0
  set generator-voltage-magnitude-setpoint 1
  set generator-mbase 100
  set generator-matpower-status 1
  set generator-maximum-real-power-output 0
  set generator-minimum-real-power-output 0
  set generator-lower-real-power-output 0
  set generator-upper-real-power-output 0
  set generator-mimimum-reactive-power-output-at-pc1 0
  set generator-maximum-reactive-power-output-at-pc1 0
  set generator-mimimum-reactive-power-output-at-pc2 0
  set generator-maximum-reactive-power-output-at-pc2 0
  set generator-ramp-rate-load 0
  set generator-ramp-rate-10-min 0
  set generator-ramp-rate-30-min 0
  set generator-ramp-rate-reactive 0
  set generator-area-participation-factor 0
    
end


to set-initial-values-of-bus
  
  set bus-number (max [bus-number] of buses) + 1
  set foreign-bus? false
  set sev3-generator-location? false
  
  ;matpower variables
  set bus-type-matpower 1
  set bus-real-power-demand 0
  set bus-reactive-power-demand 0
  set bus-shunt-conductance 0
  set bus-shunt-susceptance 0
  set bus-area-number 1
  set bus-voltage-magnitude 1
  set bus-voltage-angle 0
  set bus-base-voltage bus-voltage
  set bus-loss-zone 1
  set bus-maximum-voltage-magnitude 1.1
  set bus-minimum-voltage-magnitude 0.9

end


to set-initial-values-of-link [new-link-voltage]
 
  set link-load 0
  set link-voltage new-link-voltage
  set link-circuits 2 ;ASSUMPTION: in constructing a new line, we always give it 2 circuits
  if (link-voltage = 110) [set link-capacity link-circuits * capacity-of-a-new-110kV-circuit]
  if (link-voltage = 150) [set link-capacity link-circuits * capacity-of-a-new-150kV-circuit]
  if (link-voltage = 220) [set link-capacity link-circuits * capacity-of-a-new-220kV-circuit]
  if (link-voltage = 380) [set link-capacity link-circuits * capacity-of-a-new-380kV-circuit]
  if (link-voltage = 450) [set link-capacity link-circuits * capacity-of-a-new-450kV-circuit]
  set link-name (word [bus-name] of end1 "-" [bus-name] of end2 link-voltage)
  
  ;matpower variables
  set link-from-bus-number [bus-number] of end1 
  set link-to-bus-number [bus-number] of end2
  set link-resistance 0.00000000001
  set link-reactance 0
  set link-total-line-charging-susceptance 0
  set link-rate-a 250
  set link-rate-b 250
  set link-rate-c 250
  set link-ratio 0
  set link-angle 0
  set link-status-matpower 1
  set link-minimum-angle-difference -360
  set link-maximum-angle-difference 360
  set link-real-power-from 0
  set link-reactive-power-from 0
  set link-real-power-to 0
  set link-reactive-power-to 0
  
  ;set the link reactances based on the link distance and the voltage
  ;ASSUMPTION: assumed reactance values - based on http://www.ontario-sea.org/Storage/27/1842_When_the_Wind_Blows_over_Europe.pdf
  let reactance-per-km-380kV 0.26
  let reactance-per-km-220kV 0.32 
  let reactance-per-km-150kV 0.38
  let reactance-per-km-110kV 0.40
  let baseMVA 100
  let reactance-per-km 0
  if (link-voltage = 380 or link-voltage = 450 or link-voltage = 750) [set reactance-per-km reactance-per-km-380kV]
  if (link-voltage = 220) [set reactance-per-km reactance-per-km-220kV]
  if (link-voltage = 150) [set reactance-per-km reactance-per-km-150kV]
  if (link-voltage = 110) [set reactance-per-km reactance-per-km-110kV]
  
  let latitude-degree-km-conversion 111.25 ;based on http://en.wikipedia.org/wiki/Latitude
  let longitude-degree-km-conversion 110 ;based on http://en.wikipedia.org/wiki/Latitude
  let bus1-lat [bus-x-location] of end1 ;x is the latitude and y is the longitude here for some reason
  let bus2-lat [bus-x-location] of end2
  let bus1-long [bus-y-location] of end1
  let bus2-long [bus-y-location] of end2
  let link-distance sqrt(((bus1-lat - bus2-lat) * latitude-degree-km-conversion) ^ 2 + ((bus1-long - bus2-long) * longitude-degree-km-conversion) ^ 2)
  let link-reactance-ohm reactance-per-km * link-distance ;link reactance in ohms
  set link-reactance link-reactance-ohm / ((link-voltage ^ 2) / baseMVA) ;link reactance in per-unit
  if (link-reactance = 0) [set link-reactance 0.001] ;link reactance cannot be 0. 
   
end


to set-initial-values-of-transformer-link
  
  set transformer-link-name (word [bus-name] of end1 [bus-voltage] of end1 "-" [bus-name] of end2 [bus-voltage] of end2) 
  
  ;matpower variables 
  set transformer-link-from-bus-number [bus-number] of end1 
  set transformer-link-to-bus-number [bus-number] of end2
  set transformer-link-resistance 0.00000000001
  set transformer-link-reactance 0.00000000001
  set transformer-link-total-line-charging-susceptance 0
  set transformer-link-rate-a 250
  set transformer-link-rate-b 250
  set transformer-link-rate-c 250
  ;set transformer-link-ratio ([bus-voltage] of end1) / ([bus-voltage] of end2)
  set transformer-link-ratio 1
  set transformer-link-angle 0
  set transformer-link-status-matpower 1
  set transformer-link-minimum-angle-difference -360
  set transformer-link-maximum-angle-difference 360
  set transformer-link-real-power-from 0
  set transformer-link-reactive-power-from 0
  set transformer-link-real-power-to 0
  set transformer-link-reactive-power-to 0

end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;; VISUALIZATIONS ;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-network-visualization
  
  ask distribution-grids [
    ifelse (show-distribution-grids? = true) [set hidden? false] [set hidden? true]
    set color green
    set shape "circle"
    set size distribution-grid-peak-demand / 50
  ]
  
  ask generators [
    ifelse (show-generators? = true) [set hidden? false] [set hidden? true]
    set size sum [generator-maximum-real-power-output] of generators with [generator-name = [generator-name] of myself] / 100
    set color blue
    set shape "circle" 
  ]
  
  ask buses [
    ifelse (show-grid? = true) [set hidden? false] [set hidden? true]
    set size 0.2
    set shape "circle"
    set color black
  ]
  
  ask bus-links [
    ifelse (show-grid? = true) [set hidden? false] [set hidden? true]
    set thickness link-capacity / 2000
    if (link-voltage = 110) [set color black]
    if (link-voltage = 150) [set color blue]
    if (link-voltage = 220) [set color green]
    if (link-voltage = 380) [set color red]
    if (link-voltage = 450) [set color red + 2]
    if (link-voltage = 750) [set color pink + 2]
  ]
  
  ask transformer-links [
    ifelse (show-grid? = true) [set hidden? false] [set hidden? true]
    set color black
  ]
  
  ask buses with [bus-name != "Feda" and bus-name != "Grain" and bus-name != "Denmark"] [setxy (bus-y-location - 5.4) * 69 (bus-x-location - 52.2) * 115]
  ask buses with [bus-name = "Feda"] [setxy bus-y-location max-pycor]
  ask buses with [bus-name = "Grain"] [setxy min-pxcor bus-x-location]
  ask buses with [bus-name = "Denmark"] [setxy max-pxcor max-pycor]
  
  ask generators [setxy [xcor] of generator-bus [ycor] of generator-bus]
  ask distribution-grids [setxy [xcor] of distribution-grid-bus [ycor] of distribution-grid-bus]
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; VERIFICATION ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to verify-network
  
  verify-substation-data
  verify-line-data
  verify-connectedness
  
end


to verify-substation-data
  
  file-open "inputdata/v10/tennetsubstationdata"
  if (print-stuff?) [
    print ""
    print "MISSING SUBSTATIONS COMPARED WITH TENNET KCP DATA:"
  ]
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    if (count buses with [(bus-name = item 0 current-line) and (bus-voltage = item 1 current-line)] = 0) [
      if (print-stuff?) [print (word item 0 current-line ", " item 1 current-line ", " item 2 current-line)]
    ]
  ]
  file-close
  
  if (print-stuff?) [
    print ""
    print "EXTRA SUBSTATIONS COMPARED WITH TENNET KCP DATA:" 
  ]
  file-open "inputdata/v10/tennetsubstationdata"
  let substation-list []
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    let substation-details []
    set substation-details lput item 0 current-line substation-details
    set substation-details lput item 1 current-line substation-details
    set substation-list lput substation-details substation-list
  ]
  file-close
  
  ask buses [
    let found-match? false
    foreach substation-list [
      if (item 0 ? = bus-name and item 1 ? = bus-voltage) [
        set found-match? true
      ]
    ]
    if (found-match? = false) [
      if (print-stuff?) [print (word bus-name ", " bus-voltage ", " bus-region)]
    ]
  ]
        
end


to verify-line-data
  
  file-open "inputdata/v10/tennetlinedata"
  if (print-stuff?) [
    print ""
    print "MISSING LINES COMPARED WITH TENNET KCP DATA:"
  ]
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    if (count bus-links with [((([bus-name] of end1 = item 0 current-line and [bus-name] of end2 = item 1 current-line) or 
        ([bus-name] of end2 = item 0 current-line and [bus-name] of end1 = item 1 current-line)) and (link-voltage = item 2 current-line))] = 0) [
      if (print-stuff?) [print (word item 0 current-line ", " item 1 current-line ", " item 2 current-line)]
    ]
  ]
  file-close
  
  if (print-stuff?) [
    print ""
    print "EXTRA LINES COMPARED WITH TENNET KCP DATA:"
  ]
  file-open "inputdata/v10/tennetlinedata"
  let line-list []
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    let line-details []
    set line-details lput item 0 current-line line-details
    set line-details lput item 1 current-line line-details
    set line-details lput item 2 current-line line-details
    set line-list lput line-details line-list
  ]
  file-close
  
  ask bus-links [
    let found-match? false
    foreach line-list [
      if (item 0 ? = [bus-name] of end1 and item 1 ? = [bus-name] of end2 and item 2 ? = link-voltage) [
        set found-match? true
      ]
      if (item 0 ? = [bus-name] of end2 and item 1 ? = [bus-name] of end1 and item 2 ? = link-voltage) [
        set found-match? true
      ]
    ]
    if (found-match? = false) [
      if (print-stuff?) [print (word [bus-name] of end1 ", " [bus-name] of end2 ", " link-voltage)]
    ]
  ]
  
end


to verify-connectedness
    
    let test1? true
    let test2? true
    let test3? true
    
    ;TEST 1: check to make sure the network is fully connected
    ask buses [
      ask buses [set explored? false]
      set explored? true
      ask link-neighbors with [explored? = false] [check-interconnectedness]
      
      if (count buses with [explored? = false] > 0) [
        set test1? false
      ]
    ]
    
    ask buses [set explored? false]

    
    ;TEST 2: check to make sure no bus-links connect buses of different voltages
    ask bus-links [
      if ([bus-voltage] of end1 != [bus-voltage] of end2) [set test2? false]
    ]
    
    ;TEST 3: check to make sure no transformer-links connect buses of equal voltages
    ask transformer-links [
      if ([bus-voltage] of end1 = [bus-voltage] of end2) [set test3? false]
    ]
    
    if (print-stuff?) [
      print ""
      print "NETWORK VERIFICATION TESTS:"
      ifelse (test1? = false) [print "network verification test 1 FAILED (test 1)"] [print "network verification test 1 SUCCESSFUL"]
      ifelse (test2? = false) [print "network verification test 2 FAILED (test 2)"] [print "network verification test 2 SUCCESSFUL"]
      ifelse (test3? = false) [print "network verification test 3 FAILED"] [print "network verification test 3 SUCCESSFUL"]
    ]
    
end


to check-interconnectedness
  set explored? true
  ask link-neighbors with [explored? = false] [check-interconnectedness]
end


to verify-contingency-analysis
  
  clear-all
  
  create-buses 1 [
    set bus-voltage 100
    set-initial-values-of-bus
    setxy -50 50
  ]

  create-buses 1 [
    set bus-voltage 100
    set-initial-values-of-bus
    setxy 50 50
    create-bus-link-with bus 0 [
      set link-voltage 100
      set-initial-values-of-link link-voltage
      set link-circuits 2
      set link-capacity 0
      set link-test-contingency? 1
    ]
      
  ]
  
  create-buses 1 [
    set bus-voltage 100
    set-initial-values-of-bus
    setxy 50 -50
    create-bus-link-with bus 1 [
      set link-voltage 100
      set-initial-values-of-link link-voltage
      set link-circuits 2
      set link-capacity 0
      set link-test-contingency? 1
    ]
  ]
  
  create-buses 1 [
    set bus-voltage 100
    set-initial-values-of-bus
    setxy -50 -50
    create-bus-link-with bus 2 [
      set link-voltage 100
      set-initial-values-of-link link-voltage
      set link-circuits 3
      set link-capacity 0
      set link-test-contingency? 1
    ]
    create-bus-link-with bus 0 [
      set link-voltage 100
      set-initial-values-of-link link-voltage
      set link-circuits 1
      set link-capacity 0
      set link-test-contingency? 1
    ]
  ]
  
  create-generators 1 [
    set-initial-values-of-generator
    set generator-bus one-of buses with [bus-number = 1]
    set generator-real-power-output 100
    set generator-maximum-real-power-output 100
    setxy [xcor] of generator-bus - 10 [ycor] of generator-bus + 10
  ]
  
  create-distribution-grids 1 [
    set distribution-grid-peak-demand 100
    set distribution-grid-bus bus 2
    setxy [xcor] of distribution-grid-bus + 10 [ycor] of distribution-grid-bus - 10
  ]
  
  ;perform contingency analyis
  foreach [0 1 2] [
    set analysis-type ?
    set-power-demand-of-buses
    create-matpower-lists
    run-matpower  
    
    let matpower-link-output-data item 0 matpower-output-list
    ask bus-links [
      
      set link-load 0
      set matpower-link-results-list []
      
      foreach matpower-link-output-data [
        if (item 0 ? = link-from-bus-number AND item 1 ? = link-to-bus-number) [set matpower-link-results-list ?] ;if the numbers of the from bus and the to bus match, extract the data for this link
      ]
      
      if (matpower-link-results-list != []) [
        set link-load item 4 matpower-link-results-list * link-circuits
      ]
      show round link-load
    ]
  ]
  
  ask patches [set pcolor white]
  
  ask generators [
    set size 15
    set color blue
    set shape "circle" 
  ]
  
  ask distribution-grids [
    set size 15
    set color green
    set shape "circle"
  ]
  
  ask buses [
    set size 10
    set shape "circle"
    set color black
    set label who
    set label-color red
  ]
  
  ask bus-links [
    set thickness link-circuits
  ]
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;; LOGGING ;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to log-network
  
  set-imports-and-exports-for-logging
  set-minimum-demand-values-for-logging
  set-power-demand-of-buses
  create-matpower-lists
  log-network-list
  
end


to set-imports-and-exports-for-logging
  
  ask generators with [[foreign-bus?] of generator-bus = true] [
    set generator-maximum-real-power-output [bus-peak-import-supply] of generator-bus
    set generator-temperature-sensitive-capacity generator-maximum-real-power-output
  ]
  
  ask distribution-grids with [[foreign-bus?] of distribution-grid-bus = true] [
    set distribution-grid-peak-demand [bus-peak-export-demand] of distribution-grid-bus
    set distribution-grid-minimum-demand 0
  ]
  
end


to set-minimum-demand-values-for-logging
  
  let minimum-demand-factor 6871 / 16101 ;ratio of minimum to maximum demand over the period April 1 to Dec 1 2013, excluding anomalous minimum values
  ask distribution-grids with [[foreign-bus?] of distribution-grid-bus = false] [
    set distribution-grid-minimum-demand distribution-grid-peak-demand * minimum-demand-factor
  ]
  
end


to log-network-list
  
  ;items removed from lists since previous versions:
  ;bus elevations
  ;link lengths
  ;transformer link lengths
  ;link-fraction-underground and link-wind-exposure
  
  ;add the bus flood risk values to the bus lists
  ask buses [set bus-list lput bus-flood-risk bus-list]
  
  ;add the peak and minimum demand of the distribution grids to the bus list
  ask buses [set bus-list lput sum [distribution-grid-peak-demand] of distribution-grids with [distribution-grid-bus = myself] bus-list]
  ask buses [set bus-list lput sum [distribution-grid-minimum-demand] of distribution-grids with [distribution-grid-bus = myself] bus-list]
  
  ask generators [
    set generator-list lput generator-total-wind-capacity generator-list
    set generator-list lput generator-distributed-generation-capacity generator-list
    set generator-list lput generator-temperature-sensitive-capacity generator-list
  ]
  
  ;create the bus list to log
  let total-bus-list-to-log [] ;create an empty total bus list
  ask buses [set total-bus-list-to-log lput bus-list total-bus-list-to-log] 
  set total-bus-list-to-log sort-by [first ?1 < first ?2] total-bus-list-to-log ;sort the total bus list by bus number. this is necessary; otherwise matpower sometimes fails
  
  ;create the gen list to log
  let total-generator-list-to-log [] ;create an empty total generator list
  ask generators [set total-generator-list-to-log lput generator-list total-generator-list-to-log] ;add each generator list to the total generator list
  
  ;create the link list to log
  let total-link-list-to-log [] ;create an empty total link list
  let capacity-list []
  ask bus-links [
    set total-link-list-to-log lput link-list total-link-list-to-log ;for each link, add the link list to the total link list
    let link-capacity-list [] 
    set link-capacity-list lput link-from-bus-number link-capacity-list
    set link-capacity-list lput link-to-bus-number link-capacity-list
    set link-capacity-list lput link-capacity link-capacity-list
    set capacity-list lput link-capacity-list capacity-list
  ]
  ask transformer-links [
    set total-link-list-to-log lput transformer-link-list total-link-list-to-log ;for each transformer link, add the link list to the total link list
    let link-capacity-list [] 
    set link-capacity-list lput transformer-link-from-bus-number link-capacity-list
    set link-capacity-list lput transformer-link-to-bus-number link-capacity-list
    set link-capacity-list lput 0 link-capacity-list
    set capacity-list lput link-capacity-list capacity-list
  ]
  
  ;assemble the final list to log
  let network-list-to-log (list ticks total-bus-list-to-log total-generator-list-to-log total-link-list-to-log capacity-list) 
  
  if (scenario = "baseline scenario" and rate-of-demand-growth = 0) [ ;we only want to record this once
    file-open "outputdata/v10/scenario_baseline" 
    file-print network-list-to-log
    file-close
  ]
  
  if (scenario = "centralized generation scenario") [
    file-open (word "outputdata/v10/scenario_centralized_" rate-of-demand-growth) 
    file-print network-list-to-log
    file-close
  ]
  
  if (scenario = "distributed generation scenario") [
    file-open (word "outputdata/v10/scenario_distributed_" rate-of-demand-growth)
    file-print network-list-to-log
    file-close
  ]
  
  if (scenario = "offshore wind scenario") [
    file-open (word "outputdata/v10/scenario_offshorewind_" rate-of-demand-growth)
    file-print network-list-to-log
    file-close
  ]
  
  if (scenario = "import scenario") [
    file-open (word "outputdata/v10/scenario_import_" rate-of-demand-growth)
    file-print network-list-to-log
    file-close
  ]
  
  if (scenario = "export scenario") [
    file-open (word "outputdata/v10/scenario_export_" rate-of-demand-growth)
    file-print network-list-to-log
    file-close
  ]
  
end


to log-link-load
  
  ;remove the spaces from the scenario names for logging purposes
  let scenario2 ""
  if (scenario = "baseline scenario") [set scenario2 "baselinescenario"]
  if (scenario = "centralized generation scenario") [set scenario2 "centralizedgenerationscenario"]
  if (scenario = "distributed generation scenario") [set scenario2 "distributedgenerationscenario"]
  if (scenario = "offshore wind scenario") [set scenario2 "offshorewindscenario"]
  if (scenario = "import scenario") [set scenario2 "importscenario"]
  if (scenario = "export scenario") [set scenario2 "exportscenario"]
  
  let link-loads-to-log []
  ask bus-links [
    let bus1-lat [bus-x-location] of end1 ;x is the latitude and y is the longitude here for some reason
    let bus2-lat [bus-x-location] of end2
    let bus1-long [bus-y-location] of end1
    let bus2-long [bus-y-location] of end2
    
    let link-load-list []
    set link-load-list lput scenario2 link-load-list
    set link-load-list lput rate-of-demand-growth link-load-list
    set link-load-list lput ticks link-load-list
    set link-load-list lput link-from-bus-number link-load-list
    set link-load-list lput bus1-lat link-load-list
    set link-load-list lput bus1-long link-load-list
    set link-load-list lput link-to-bus-number link-load-list
    set link-load-list lput bus2-lat link-load-list
    set link-load-list lput bus2-long link-load-list
    set link-load-list lput link-voltage link-load-list
    set link-load-list lput link-load link-load-list
    set link-load-list lput link-capacity link-load-list
    set link-loads-to-log lput link-load-list link-loads-to-log
  ]
  file-open "outputdata/v10/linkloads"
  file-print link-loads-to-log
  file-close
  
end


to log-current-grid

  setup-the-landscape
  let capacity-list-to-export []
  ask bus-links [
    let temp-link-list []
    set temp-link-list lput link-name temp-link-list
    set temp-link-list lput link-from-bus-number temp-link-list
    set temp-link-list lput link-to-bus-number temp-link-list
    set temp-link-list lput link-voltage temp-link-list
    set temp-link-list lput link-capacity temp-link-list
    set capacity-list-to-export lput temp-link-list capacity-list-to-export
  ]
  update-line-capacities
  let load-list-to-export []
  ask bus-links [
    let temp-link-list []
    set temp-link-list lput link-name temp-link-list
    set temp-link-list lput link-from-bus-number temp-link-list
    set temp-link-list lput link-to-bus-number temp-link-list
    set temp-link-list lput link-voltage temp-link-list
    set temp-link-list lput link-load temp-link-list
    set load-list-to-export lput temp-link-list load-list-to-export
  ]
  let total-list-to-export []
  set total-list-to-export lput capacity-list-to-export total-list-to-export
  set total-list-to-export lput load-list-to-export total-list-to-export

  file-open "outputdata/v10/currentgrid"
  file-print total-list-to-export
  file-close
  
end


to log-original-capacities
  
  setup-the-landscape
  repeat 41 [grow-transmission-grid]
  
  let capacity-list-to-export []
  ask bus-links [
    let temp-link-list []
    set temp-link-list lput link-name temp-link-list
    set temp-link-list lput link-from-bus-number temp-link-list
    set temp-link-list lput link-to-bus-number temp-link-list
    set temp-link-list lput link-voltage temp-link-list
    set temp-link-list lput link-capacity temp-link-list
    set capacity-list-to-export lput temp-link-list capacity-list-to-export
  ]
  
  file-open "outputdata/v10/originalcapacities"
  file-print capacity-list-to-export
  file-close
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;; VISUALIZATIONS ;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to visualize-scenario-capacities
  
  set-scenario-capacities
  set-scenario-generator-outputs
  visualize-capacity-centralized
  visualize-capacity-distributed
  visualize-capacity-offshorewind
  visualize-capacity-import
  
end


to set-scenario-capacities
  
  file-open "outputdata/scenariocapacities/scenario_baseline"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask bus-links with [([bus-number] of end1 = item 0 current-line and [bus-number] of end2 = item 1 current-line) or ([bus-number] of end1 = item 1 current-line and [bus-number] of end2 = item 0 current-line)] [
      set link-capacity-baseline item 2 current-line
    ]
  ]
  file-close
  
  file-open "outputdata/scenariocapacities/scenario_centralized"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask bus-links with [([bus-number] of end1 = item 0 current-line and [bus-number] of end2 = item 1 current-line) or ([bus-number] of end1 = item 1 current-line and [bus-number] of end2 = item 0 current-line)] [
      set link-capacity-centralized item 2 current-line
    ]
  ]
  file-close
  
  file-open "outputdata/scenariocapacities/scenario_distributed"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask bus-links with [([bus-number] of end1 = item 0 current-line and [bus-number] of end2 = item 1 current-line) or ([bus-number] of end1 = item 1 current-line and [bus-number] of end2 = item 0 current-line)] [
      set link-capacity-distributed item 2 current-line
    ]
  ]
  file-close
  
  file-open "outputdata/scenariocapacities/scenario_offshorewind"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask bus-links with [([bus-number] of end1 = item 0 current-line and [bus-number] of end2 = item 1 current-line) or ([bus-number] of end1 = item 1 current-line and [bus-number] of end2 = item 0 current-line)] [
      set link-capacity-offshorewind item 2 current-line
    ]
  ]
  file-close
  
  file-open "outputdata/scenariocapacities/scenario_import"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask bus-links with [([bus-number] of end1 = item 0 current-line and [bus-number] of end2 = item 1 current-line) or ([bus-number] of end1 = item 1 current-line and [bus-number] of end2 = item 0 current-line)] [
      set link-capacity-import item 2 current-line
    ]
  ]
  file-close
  
  ask bus-links with [link-capacity-baseline = 0] [
    set capacity-ratio 0
  ]
  
end


to set-scenario-generator-outputs
  
  file-open "outputdata/scenariocapacities/genoutputs_scenario_baseline"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask generators with [[bus-number] of generator-bus = item 0 current-line] [
      set generator-capacity-baseline item 1 current-line
    ]
  ]
  file-close
  
  file-open "outputdata/scenariocapacities/genoutputs_scenario_centralized"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask generators with [[bus-number] of generator-bus = item 0 current-line] [
      set generator-capacity-centralized item 1 current-line
    ]
  ]
  file-close
  
  file-open "outputdata/scenariocapacities/genoutputs_scenario_distributed"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask generators with [[bus-number] of generator-bus = item 0 current-line] [
      set generator-capacity-distributed item 1 current-line
    ]
  ]
  file-close
  
  file-open "outputdata/scenariocapacities/genoutputs_scenario_offshorewind"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask generators with [[bus-number] of generator-bus = item 0 current-line] [
      set generator-capacity-offshorewind item 1 current-line
    ]
  ]
  file-close
  
  file-open "outputdata/scenariocapacities/genoutputs_scenario_import"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    ask generators with [[bus-number] of generator-bus = item 0 current-line] [
      set generator-capacity-import item 1 current-line
    ]
  ]
  file-close
  
end


to visualize-capacity-centralized
  
  ask bus-links with [link-capacity-baseline > 0] [
    set capacity-ratio link-capacity-centralized - link-capacity-baseline
  ]
  
  let max-ratio max [capacity-ratio] of bus-links
  ask bus-links[
    set color -5 * (capacity-ratio / max-ratio) + 18
    set thickness 2
    if (capacity-ratio = 0) [set hidden? false set color 8 set thickness 1]
  ]
  
  ask generators [set size generator-capacity-centralized / 100]
  ask buses [set hidden? true]
  ask distribution-grids [set hidden? true]
  ask transformer-links [set hidden? true]
  
  export-view "outputdata/scenariocapacities/linecapacities_centralized.png"
  
end


to visualize-capacity-distributed
  
  ask bus-links with [link-capacity-baseline > 0] [
    set capacity-ratio link-capacity-distributed - link-capacity-baseline
  ]
  
  let max-ratio max [capacity-ratio] of bus-links
  ask bus-links [
    set color -5 * (capacity-ratio / max-ratio) + 18
    set thickness 2
    if (capacity-ratio = 0) [set hidden? false set color 8 set thickness 1]
  ]
  
  ask generators [set size generator-capacity-distributed / 100]
  ask buses [set hidden? true]
  ask distribution-grids [set hidden? true]
  ask transformer-links [set hidden? true]
  
  export-view "outputdata/scenariocapacities/linecapacities_distributed.png"
  
end


to visualize-capacity-offshorewind
  
  ask bus-links with [link-capacity-baseline > 0] [
    set capacity-ratio link-capacity-offshorewind - link-capacity-baseline
  ]
  
  let max-ratio max [capacity-ratio] of bus-links
  ask bus-links [
    set color -5 * (capacity-ratio / max-ratio) + 18
    set thickness 2
    if (capacity-ratio = 0) [set hidden? false set color 8 set thickness 1]
  ]
  
  ask generators [set size generator-capacity-offshorewind / 100]
  ask buses [set hidden? true]
  ask distribution-grids [set hidden? true]
  ask transformer-links [set hidden? true]
  
  export-view "outputdata/scenariocapacities/linecapacities_offshorewind.png"
  
end


to visualize-capacity-import
  
  ask bus-links with [link-capacity-baseline > 0] [
    set capacity-ratio link-capacity-import - link-capacity-baseline
  ]
  
  let max-ratio max [capacity-ratio] of bus-links
  ask bus-links [
    set color -5 * (capacity-ratio / max-ratio) + 18
    set thickness 2
    if (capacity-ratio = 0) [set hidden? false set color 8 set thickness 1]
  ]
  
  ask generators [set size generator-capacity-import / 100]
  ask buses [set hidden? true]
  ask distribution-grids [set hidden? true]
  ask transformer-links [set hidden? true]
  
  export-view "outputdata/scenariocapacities/linecapacities_import.png"
  
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;; OTHER VISUALIZATIONS ;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


to visualize-flood-vulnerability
  
  ask turtles [set hidden? true]
  ask links [set hidden? true]
  ask buses [
    set hidden? false
    set size 5
  ]
  ask buses with [bus-flood-risk = 0] [set color blue]
  ask buses with [bus-flood-risk = 1] [set color blue]
  ask buses with [bus-flood-risk = 2] [set color blue]
  ask buses with [bus-flood-risk = 3] [set color blue]
  ask buses with [bus-flood-risk = 4] [set color blue]
  ask buses with [bus-flood-risk = 5] [set color red]
  
end


to visualize-heatwave-vulnerability
  
  ask turtles [set hidden? true]
  ask links [set hidden? true]
  ask generators [
    set hidden? false
    set size generator-maximum-real-power-output / 50
  ]
  ask generators with [generator-maximum-real-power-output > 0] [
    if (generator-temperature-sensitive-capacity / generator-maximum-real-power-output > 7 / 8) [set color magenta]
    if (generator-temperature-sensitive-capacity / generator-maximum-real-power-output <= 7 / 8 and generator-temperature-sensitive-capacity / generator-maximum-real-power-output > 6 / 8) [set color red]
    if (generator-temperature-sensitive-capacity / generator-maximum-real-power-output <= 6 / 8 and generator-temperature-sensitive-capacity / generator-maximum-real-power-output > 5 / 8) [set color orange]
    if (generator-temperature-sensitive-capacity / generator-maximum-real-power-output <= 5 / 8 and generator-temperature-sensitive-capacity / generator-maximum-real-power-output > 4 / 8) [set color yellow]
    if (generator-temperature-sensitive-capacity / generator-maximum-real-power-output <= 4 / 8 and generator-temperature-sensitive-capacity / generator-maximum-real-power-output > 3 / 8) [set color lime]
    if (generator-temperature-sensitive-capacity / generator-maximum-real-power-output <= 3 / 8 and generator-temperature-sensitive-capacity / generator-maximum-real-power-output > 2 / 8) [set color cyan]
    if (generator-temperature-sensitive-capacity / generator-maximum-real-power-output <= 2 / 8 and generator-temperature-sensitive-capacity / generator-maximum-real-power-output > 1 / 8) [set color sky]
    if (generator-temperature-sensitive-capacity / generator-maximum-real-power-output <= 1 / 8) [set color blue]
  ]
  
end


to visualize-new-lines
  
  setup-the-landscape
  ask bus-links [set color gray]
  ask generators [set hidden? true]
  ask distribution-grids [set hidden? true]
  
  file-open "inputdata/v10/newsubstations"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    create-buses 1 [
      set bus-voltage item 1 current-line
      set-initial-values-of-bus
      set bus-name item 0 current-line
      set bus-x-location item 2 current-line
      set bus-y-location item 3 current-line
      set bus-region item 4 current-line
      set bus-flood-risk item 5 current-line
      set foreign-bus? false
      set color red
    ]
  ]
  file-close
  
  file-open "inputdata/v10/newlines"
  while [not file-at-end?] [
    let current-line read-from-string (word "[" file-read-line "]")
    let bus1-name (item 0 current-line)
    let bus2-name (item 1 current-line)
    let line-voltage (item 2 current-line)
    let bus1 one-of buses with [bus-name = bus1-name and bus-voltage = line-voltage]
    let bus2 one-of buses with [bus-name = bus2-name and bus-voltage = line-voltage]
    
    ask bus1 [
      create-bus-link-with bus2 [
        set link-voltage item 2 current-line
        set-initial-values-of-link link-voltage
        set link-circuits item 3 current-line
        set link-capacity item 4 current-line * link-circuits
        set color red
        set thickness 5
        
        ;power factor correction
        let power-factor 0.98 ;ASSUMPTION: assumed value of power factor
        if (link-voltage != 450) [set link-capacity link-capacity * power-factor]
      ]
    ]
  ]
  file-close
  
  fill-missing-data
  
  ask buses with [foreign-bus? = false and (bus-name = "Denmark" or bus-name = "Wesel")] [setup-foreign-bus]
  
  ask buses with [bus-name != "Feda" and bus-name != "Grain" and bus-name != "Denmark"] [setxy (bus-y-location - 5.4) * 69 (bus-x-location - 52.2) * 115]
  ask buses with [bus-name = "Feda"] [setxy bus-y-location max-pycor]
  ask buses with [bus-name = "Grain"] [setxy min-pxcor bus-x-location]
  ask buses with [bus-name = "Denmark"] [setxy max-pxcor max-pycor]
  
  ask generators [setxy [xcor] of generator-bus [ycor] of generator-bus]
  ask distribution-grids [setxy [xcor] of distribution-grid-bus [ycor] of distribution-grid-bus]
  
end
 



  
  
@#$#@#$#@
GRAPHICS-WINDOW
273
16
799
666
139
167
1.85
1
10
1
1
1
0
0
0
1
-139
139
-167
167
1
1
1
ticks
30.0

BUTTON
20
21
216
54
NIL
setup-the-landscape
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
21
59
216
92
NIL
grow-transmission-grid
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
285
669
412
702
show-grid?
show-grid?
0
1
-1000

SWITCH
415
669
580
702
show-generators?
show-generators?
0
1
-1000

SWITCH
583
669
787
702
show-distribution-grids?
show-distribution-grids?
0
1
-1000

SWITCH
21
574
241
607
print-matpower-data?
print-matpower-data?
1
1
-1000

CHOOSER
19
198
200
243
EHV-contingency-type
EHV-contingency-type
0 1 2
2

CHOOSER
20
247
200
292
HV-contingency-type
HV-contingency-type
0 1 2
1

BUTTON
22
97
217
130
NIL
grow-transmission-grid
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
21
701
244
734
NIL
verify-network
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
21
663
244
696
NIL
verify-contingency-analysis
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
832
170
1229
290
capacity distribution of 110kV lines
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range min [link-capacity] of bus-links with [link-voltage = 110] max [link-capacity] of bus-links  with [link-voltage = 110]\nset-plot-y-range 0 count bus-links with [link-voltage = 110]\nset-histogram-num-bars 25"
PENS
"default" 1.0 1 -16777216 true "" "histogram [link-capacity] of bus-links with [link-voltage = 110]"

PLOT
832
292
1229
413
capacity distribution of 150kV lines
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range min [link-capacity] of bus-links with [link-voltage = 150] max [link-capacity] of bus-links  with [link-voltage = 150]\nset-plot-y-range 0 count bus-links with [link-voltage = 150]\nset-histogram-num-bars 25"
PENS
"default" 1.0 1 -16777216 true "" "histogram [link-capacity] of bus-links with [link-voltage = 150]"

PLOT
835
418
1231
543
capacity distribution of 220kV lines
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range min [link-capacity] of bus-links with [link-voltage = 220] max [link-capacity] of bus-links  with [link-voltage = 220]\nset-plot-y-range 0 count bus-links with [link-voltage = 220]\nset-histogram-num-bars 25"
PENS
"default" 1.0 1 -16777216 true "" "histogram [link-capacity] of bus-links with [link-voltage = 220]"

PLOT
836
549
1230
690
capacity distribution of 380kV and 450kV lines
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-plot-x-range min [link-capacity] of bus-links with [link-voltage >= 380] max [link-capacity] of bus-links  with [link-voltage >= 380]\nset-plot-y-range 0 count bus-links with [link-voltage >= 380]\nset-histogram-num-bars 25"
PENS
"default" 1.0 1 -16777216 true "" "histogram [link-capacity] of bus-links with [link-voltage >= 380]"

PLOT
833
13
1227
163
mean link capacity
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"110kV" 1.0 0 -16777216 true "" "plot mean [link-capacity] of bus-links with [link-voltage = 110]"
"150kV" 1.0 0 -13345367 true "" "plot mean [link-capacity] of bus-links with [link-voltage = 150]"
"220kV" 1.0 0 -10899396 true "" "plot mean [link-capacity] of bus-links with [link-voltage = 220]"
"380kV" 1.0 0 -2674135 true "" "plot mean [link-capacity] of bus-links with [link-voltage = 380]"

PLOT
1237
10
1693
179
generation capacity and peak demand
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"generation capacity" 1.0 0 -13345367 true "" "plot sum [generator-maximum-real-power-output] of generators with [[foreign-bus?] of generator-bus = false]"
"peak demand" 1.0 0 -10899396 true "" "plot sum [distribution-grid-peak-demand] of distribution-grids"
"generator output" 1.0 0 -955883 true "" "plot sum [generator-real-power-output] of generators"
"distr gen capacity" 1.0 0 -7500403 true "" "plot sum [generator-distributed-generation-capacity] of generators"
"offshore wind capacity" 1.0 0 -2674135 true "" "plot sum [generator-total-wind-capacity] of generators"
"temp sensitive cap" 1.0 0 -6459832 true "" "plot sum [generator-temperature-sensitive-capacity] of generators"

PLOT
1238
190
1692
360
peak imports
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Germany" 1.0 0 -16777216 true "" "plot sum [bus-peak-import-supply] of buses with [bus-region = \"Germany\"]"
"Belgium" 1.0 0 -10899396 true "" "plot sum [bus-peak-import-supply] of buses with [bus-region = \"Belgium\"]"
"Norway" 1.0 0 -2674135 true "" "plot sum [bus-peak-import-supply] of buses with [bus-region = \"Norway\"]"
"England" 1.0 0 -955883 true "" "plot sum [bus-peak-import-supply] of buses with [bus-region = \"England\"]"
"Denmark" 1.0 0 -7500403 true "" "plot sum [bus-peak-import-supply] of buses with [bus-region = \"Denmark\"]"

PLOT
1239
367
1690
541
peak exports
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Germany" 1.0 0 -16777216 true "" "plot sum [bus-peak-export-demand] of buses with [bus-region = \"Germany\"]"
"Belgium" 1.0 0 -10899396 true "" "plot sum [bus-peak-export-demand] of buses with [bus-region = \"Belgium\"]"
"Norway" 1.0 0 -2674135 true "" "plot sum [bus-peak-export-demand] of buses with [bus-region = \"Norway\"]"
"England" 1.0 0 -955883 true "" "plot sum [bus-peak-export-demand] of buses with [bus-region = \"England\"]"
"Denmark" 1.0 0 -7500403 true "" "plot sum [bus-peak-export-demand] of buses with [bus-region = \"Denmark\"]"

SWITCH
18
322
236
355
update-line-capacities?
update-line-capacities?
1
1
-1000

SWITCH
17
358
236
391
construct-new-lines?
construct-new-lines?
0
1
-1000

CHOOSER
16
433
238
478
scenario
scenario
"baseline scenario" "centralized generation scenario" "distributed generation scenario" "offshore wind scenario" "import scenario" "export scenario"
3

BUTTON
22
136
217
169
NIL
setup-and-go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
22
537
238
570
log-network?
log-network?
1
1
-1000

SLIDER
15
395
238
428
rate-of-demand-growth
rate-of-demand-growth
-5
5
3
1
1
NIL
HORIZONTAL

SWITCH
21
502
237
535
log-link-loads?
log-link-loads?
1
1
-1000

SWITCH
21
611
241
644
print-stuff?
print-stuff?
0
1
-1000

BUTTON
24
755
242
788
NIL
log-current-grid
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
23
802
241
835
NIL
log-original-capacities
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
249
753
461
792
turn logging off\nset contingency types to 2&1
12
0.0
1

TEXTBOX
251
793
401
841
turn logging off\nconstruct new lines on\nupdate line capacities off
12
0.0
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup-the-landscape</setup>
    <go>grow-transmission-grid</go>
    <final>log-network</final>
    <timeLimit steps="40"/>
    <enumeratedValueSet variable="show-generators?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="line-capacity-upgrade-time">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-threshold-for-380kV">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="line-construction-time">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-line-capacities?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-stuff?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="line-planning-time">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-matpower-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-distribution-grids?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="construct-new-EHV-lines?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="construct-loop-structures?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-grid?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scenario">
      <value value="&quot;baseline scenario&quot;"/>
      <value value="&quot;centralized generation scenario&quot;"/>
      <value value="&quot;distributed generation scenario&quot;"/>
      <value value="&quot;offshore wind scenario&quot;"/>
      <value value="&quot;import scenario&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HV-contingency-type">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="capacity-threshold-for-750kV">
      <value value="5000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EHV-contingency-type">
      <value value="2"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TestExperiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup-the-landscape</setup>
    <go>grow-transmission-grid</go>
    <timeLimit steps="41"/>
    <enumeratedValueSet variable="construct-new-lines?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="log-link-loads?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-matpower-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-distribution-grids?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scenario">
      <value value="&quot;baseline scenario&quot;"/>
      <value value="&quot;centralized generation scenario&quot;"/>
      <value value="&quot;distributed generation scenario&quot;"/>
      <value value="&quot;offshore wind scenario&quot;"/>
      <value value="&quot;import scenario&quot;"/>
      <value value="&quot;export scenario&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-line-capacities?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-demand-growth">
      <value value="0"/>
      <value value="1.5"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HV-contingency-type">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-stuff?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="log-network?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-generators?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EHV-contingency-type">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-grid?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="TestExperiment2" repetitions="1" runMetricsEveryStep="false">
    <setup>setup-the-landscape</setup>
    <go>grow-transmission-grid</go>
    <timeLimit steps="40"/>
    <enumeratedValueSet variable="construct-new-lines?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="log-link-loads?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-matpower-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-distribution-grids?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scenario">
      <value value="&quot;baseline scenario&quot;"/>
      <value value="&quot;centralized generation scenario&quot;"/>
      <value value="&quot;distributed generation scenario&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-line-capacities?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-demand-growth">
      <value value="0"/>
      <value value="1.5"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HV-contingency-type">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-stuff?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="log-network?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-generators?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EHV-contingency-type">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-grid?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="FinalExperiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup-the-landscape</setup>
    <go>grow-transmission-grid</go>
    <timeLimit steps="41"/>
    <enumeratedValueSet variable="construct-new-lines?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="log-link-loads?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-matpower-data?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-distribution-grids?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="scenario">
      <value value="&quot;import scenario&quot;"/>
      <value value="&quot;export scenario&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-line-capacities?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-demand-growth">
      <value value="0"/>
      <value value="1.5"/>
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HV-contingency-type">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="print-stuff?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="log-network?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-generators?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="EHV-contingency-type">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-grid?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
