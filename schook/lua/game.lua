#****************************************************************************
#**
#**  File     :  /lua/game.lua
#**  Author(s): John Comes
#**
#**  Summary  : Script full of overall game functions
#**
#**  Copyright � 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************

VeteranDefault = {
    Level1 = 25,
    Level2 = 100,
    Level3 = 250,
    Level4 = 500,
    Level5 = 1000,
}


local BuffFieldBlueprint = import('/lua/sim/BuffField.lua').BuffFieldBlueprint
##################################################################
## SERAPHIM BUFF FIELDS
##################################################################

BuffFieldBlueprint {                         # Seraphim ACU Restoration
    Name = 'SeraphimACURegenBuffField',
    AffectsUnitCategories = 'ALLUNITS',
    AffectsAllies = false,
    AffectsVisibleEnemies = false,
    AffectsOwnUnits = true,
    AffectsSelf = true,
    DisableInTransport = true,
    InitiallyEnabled = false,
    MaintenanceConsumptionPerSecondEnergy = 0,
    Radius = 15,
    Buffs = {
        'SeraphimACURegenAura',
    },
}

BuffFieldBlueprint {                         # Seraphim ACU Advanced Restoration
    Name = 'SeraphimAdvancedACURegenBuffField',
    AffectsUnitCategories = 'ALLUNITS',
    AffectsAllies = false,
    AffectsVisibleEnemies = false,
    AffectsOwnUnits = true,
    AffectsSelf = true,
    DisableInTransport = true,
    InitiallyEnabled = false,
    MaintenanceConsumptionPerSecondEnergy = 0,
    Radius = 15,
    Buffs = {
        'SeraphimAdvancedACURegenAura',
    },
}



# Return the total time (in seconds), energy, and mass it will take for the given
# builder to create a unit of type target_bp.
#
# targetData may also be an "Enhancement" section of a unit's blueprint rather than
# a full blueprint.
function GetConstructEconomyModel(builder, targetData)

    local builder_bp = builder:GetBlueprint()
    
    # 'rate' here is how fast we build relative to a unit with build rate of 1
    local rate = builder:GetBuildRate()

    local time = targetData.BuildTime
    local mass = targetData.BuildCostMass
    local energy = targetData.BuildCostEnergy

    # apply penalties/bonuses to effective time
    local time_mod = builder.BuildTimeModifier or 0
    time = time * (100 + time_mod)*.01
    if time<.1 then time = .1 end

    # apply penalties/bonuses to effective energy cost
    local energy_mod = builder.EnergyModifier or 0
    energy = energy * (100 + energy_mod)*.01
    if energy<0 then energy = 0 end

    # apply penalties/bonuses to effective mass cost
    local mass_mod = builder.MassModifier or 0
    mass = mass * (100 + mass_mod)*.01
    if mass<0 then mass = 0 end

    return time/rate, energy, mass
end


###added for CBFP


SpecialWepRestricted = false
UnitCatRestricted = false
_UnitRestricted_cache = {}


# -------------------------------------------------------------------------------------------------------------
# UNIT RESTRICTION FUNCTIONS   [119] [157]


function UnitRestricted(unit)
    # checks if the unit is allowed to be build in the current game.

    if not CheckUnitRestrictionsEnabled() then     # if no restrictions defined then dont bother
        return false
    end

    local unitId = unit:GetUnitId()
    if _UnitRestricted_cache[unitId] then          # use cache if available
        return _UnitRestricted_cache[unitId]
    end

    CacheRestrictedUnitLists()
    _UnitRestricted_cache[unitId] = false
    for k, cat in UnitCatRestricted do
        if EntityCategoryContains( cat, unitId ) then   # because of this function we need the unit, not the unitId
            _UnitRestricted_cache[unitId] = true
            break
        end
    end

    return _UnitRestricted_cache[unitId]
end


function WeaponRestricted(weaponLabel)
    # tells you whether a weapon should be disabled (according to the unit restrictions)

    if not CheckUnitRestrictionsEnabled() then     # if no restrictions defined then dont bother
        return false
    end
    CacheRestrictedUnitLists()
    return SpecialWepRestricted[weaponLabel]
end


function NukesRestricted()
    return WeaponRestricted('StrategicMissile')
end


function TacticalMissilesRestricted()
    return WeaponRestricted('TacticalMissile')
end


# -------------------------------------------------------------------------------------------------------------
# HELPER FUNCTIONS

function CheckUnitRestrictionsEnabled()
    # tells you whether unit restrictions are enabled
    if ScenarioInfo.Options.RestrictedCategories then return true end
    return false
end

function CacheRestrictedUnitLists()
    # create tables of restricted units and special weapons. Only need to run once per game

    # check if we need to do this function at all
    if type(UnitCatRestricted) == 'table' then
        return
    end

    SpecialWepRestricted = {}
    UnitCatRestricted = {}
    local restrictedUnits = import('/lua/ui/lobby/restrictedUnitsData.lua').restrictedUnits
    local c

    # loops through enabled restrictions
    for k, restriction in ScenarioInfo.Options.RestrictedCategories do 

        # create a list of all unit category restrictions. TO be clear, this results in a table of categories
        # So, for example:   { categories.TECH1, categories.TECH2, categories.MASSFAB }
        if restrictedUnits[restriction].categories then
            for l, cat in restrictedUnits[restriction].categories do
                c = cat
                if type(c) == 'string' then c = ParseEntityCategory(c) end
                table.insert( UnitCatRestricted, c )
            end
        end

        # create a list of restricted special weapons (nukes, tactical missiles)
        if restrictedUnits[restriction].specialweapons then   
            for l, cat in restrictedUnits[restriction].specialweapons do

                # strategic missiles
                if cat == 'StrategicMissile' or cat == 'strategicmissile' or cat == 'sm' or cat == 'SM' then
                    SpecialWepRestricted['StrategicMissile'] = true

                # tactical missiles
                elseif cat == 'TacticalMissile' or cat == 'tacticalmissile' or cat == 'tm' or cat == 'TM' then
                    SpecialWepRestricted['TacticalMissile'] = true

                # mod added weapons
                else
                    SpecialWepRestricted[cat] = true
                end
            end
        end
    end
end