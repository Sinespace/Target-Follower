
myObj = Space.Host.ExecutingObject
myPlayer = Space.Scene.PlayerAvatar

targetObj = nil

follower = Space.Host.GetReference("Follower")

-- Variables to control how fast the follower moves/turns
turnSpeed = turnSpeed or 1
moveSpeed = moveSpeed or 1

-- If farther than maxDistance, follower will teleport closer first.
maxDistance = maxDistance or 30

-- Follower may want to position itself above/in front/beside the target rather than on it.
targetOffsetX = targetOffsetX or 0
targetOffsetY = targetOffsetY or 1
targetOffsetZ = targetOffsetZ or 3

-- Should the follower face the target no matter what position it is trying to acquire.
alwaysFaceTarget = alwaysFaceTarget or false

-- Should the follower act as if it is not parented to the prefab, in the case that it is an attachment.
movableSource = movableSource or false

-- Teleport "out" delay
teleportPreDelay = teleportPreDelay or 0
if teleportPreDelay < 0 then
    teleportPreDelay = 0
end

-- teleport "in" delay before starting to move
teleportPostDelay = teleportPostDelay or 0
if teleportPostDelay < 0 then
    teleportPostDelay = 0
end

-- How close does the follower have to be to consider it 'arrived'
arriveDistance = arriveDistance or 0.1
if arriveDistance < 0.1 then
    arriveDistance = 0.1
end

-- How tightly aimed at the target does the follower have to be to consider it looking at it.
aimAngle = aimAngle or 3
if aimAngle < 0.1 then
    aimAngle = 0.1
end

-- Are we attached to an avatar, it changes...stuff.
isAvatarAttachment = false

-- Are we currently moving or are we 'settled'
isMoving = false

-- Are we currently turning or are we aimed.
isTurning = false

targetLocation = nil
lookAtLocation = nil
currentDistance = nil
vectorToWaypoint = nil
updateToRotation = nil
lastLocation = nil
lastRotation = nil
lastAngle = nil

hasTeleported = false
teleportDistance = nil
teleportRay = nil
teleportTime = nil

function onUpdate()
    -- Every frame...
    if follower ~= nil and follower.Active then
        if movableSource then
            if lastLocation ~= nil then
                follower.WorldPosition = lastLocation
            end
            if lastRotation ~= nil then
                follower.WorldRotation = lastRotation
            end
        end
        targetLocation = targetObj.GameObject.WorldPosition + (targetObj.GameObject.Forward * targetOffsetZ) + (targetObj.GameObject.Up * targetOffsetY) + (targetObj.GameObject.Right * targetOffsetX)
        currentDistance = targetLocation.Distance(follower.WorldPosition)
        if currentDistance > maxDistance and teleportDistance == nil then
            if not isMoving then
                isMoving = true
                Space.Host.InvokeEvent("Moving")
            end
            Space.Host.InvokeEvent("Teleport")
            teleportDistance = maxDistance
            teleportTime = Space.Time
        end
        if teleportDistance ~= nil then
            if not hasTeleported and (Space.Time - teleportTime) >= teleportPreDelay then
                hasTeleported = true
                teleportRay = Space.Physics.RayCastSingle(targetLocation, (follower.WorldPosition - targetLocation).Normalised, maxDistance)
                if teleportRay ~= nil and teleportRay.ContainsHit then
                    -- We hit something!
                    teleportDistance = teleportRay.Distance
                end
                follower.WorldPosition = follower.WorldPosition + ((targetLocation - follower.WorldPosition).Normalised * ((currentDistance - teleportDistance) + 0.5))
            elseif hasTeleported and (Space.Time - teleportTime) >= (teleportPreDelay + teleportPostDelay) then
                teleportDistance = nil
                teleportRay = nil
                hasTeleported = false
                teleportTime = nil
            end
        else
            if currentDistance > arriveDistance then
                if not isMoving then
                    isMoving = true
                    Space.Host.InvokeEvent("Moving")
                end
            else
                if isMoving then
                    isMoving = false
                    Space.Host.InvokeEvent("Arrived")
                end
            end
            -- Lerp our position between our current position and the position we want to be in.
            follower.WorldPosition = follower.WorldPosition.Lerp(targetLocation, moveSpeed * Space.DeltaTime)
        end
        if alwaysFaceTarget then
            lookAtLocation = targetObj.GameObject.WorldPosition + (targetObj.GameObject.Up * targetOffsetY)
            vectorToWaypoint = lookAtLocation - follower.WorldPosition
        else
            vectorToWaypoint = targetLocation - follower.WorldPosition
        end
        -- Calculate the direction we'd like to be facing (toward our target)
        updateToRotation = Quaternion.LookRotation(vectorToWaypoint)
        -- Lerp our rotation between our current rotation and the rotation we need to be on.
        follower.WorldRotation = follower.WorldRotation.Lerp(updateToRotation, turnSpeed * Space.DeltaTime)
        lastAngle = follower.WorldRotation.Angle(updateToRotation)
        if lastAngle > aimAngle and not isTurning then
            isTurning = true
            Space.Host.InvokeEvent("Turning")
        elseif lastAngle <= aimAngle and isTurning then
            isTurning = false
            Space.Host.InvokeEvent("Aimed")
        end
        -- If our source is moveable, we need to record this between frames.
        if movableSource then
            lastLocation = follower.WorldPosition
            lastRotation = follower.WorldRotation
        end
        -- Wash, rinse, repeat.
    end
end

function changeTarget(newTarget)
    targetObj = newTarget
end

function init()
    -- Bind to OnUpdate so we run every frame.
    myObj.OnUpdate(onUpdate)

    -- Check if follower is attached to an avatar.
    if myObj.Root.Avatar ~= nil then
        -- We're attached to an avatar.
        isAvatarAttachment = true
        targetObj = myObj.Root
    else
        -- We're not attached to an avatar.
        isAvatarAttachment = false
        targetObj = myPlayer
    end

    --Space.Shared.RegisterFunction("space.sine.follower", "retarget", changeTarget)
end

init()
