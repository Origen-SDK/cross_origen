module CrossOrigen
  MAJOR = 0
  MINOR = 3
  BUGFIX = 0
  DEV = 19

  VERSION = [MAJOR, MINOR, BUGFIX].join(".") + (DEV ? ".pre#{DEV}" : '')
end
