module CrossOrigen
  MAJOR = 1
  MINOR = 2
  BUGFIX = 3
  DEV = nil

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
