return function(mod)
  if mod.developer == true then
    mod.commands:register("adaptive_trainers_test:developer_probe",
      function() return true end)
  end
end
