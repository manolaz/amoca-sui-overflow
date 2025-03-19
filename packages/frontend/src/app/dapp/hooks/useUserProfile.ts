'use client'

import { useSuiClient } from '@mysten/dapp-kit'
import { useQuery } from '@tanstack/react-query'
import { useCurrentAccount } from '@mysten/dapp-kit'
import { NETWORK_CONFIG } from '~~/config/network'
import { bcs } from '@mysten/sui.js/bcs'
import useNetworkConfig from '~~/hooks/useNetworkConfig'

export type Experience = {
  company: string
  title: string
  startDate: string
  endDate: string
  description: string
}

export type Education = {
  institution: string
  degree: string
  field: string
  startDate: string
  endDate: string
}

export type Skill = {
  name: string
  endorsements: number
}

export type Profile = {
  id: string
  owner: string
  name: string
  headline: string
  bio: string
  profileImageUrl: string
  location: string
  contactEmail: string
  experiences: Experience[]
  education: Education[]
  skills: Skill[]
  connections: string[]
}

/**
 * Hook to fetch the current user's profile
 */
export default function useUserProfile() {
  const currentAccount = useCurrentAccount()
  const suiClient = useSuiClient()
  const { useNetworkVariable } = useNetworkConfig()
  const packageId = useNetworkVariable('CONTRACT_PACKAGE_VARIABLE_NAME')

  return useQuery({
    queryKey: ['userProfile', currentAccount?.address, packageId],
    queryFn: async (): Promise<Profile | null> => {
      if (!currentAccount?.address || !packageId) {
        return null
      }

      try {
        // Get user's owned objects of type Profile
        const userObjects = await suiClient.getOwnedObjects({
          owner: currentAccount.address,
          filter: {
            StructType: `${packageId}::profile::Profile`,
          },
          options: {
            showContent: true,
            showType: true,
          },
        })

        if (!userObjects.data.length) {
          return null
        }

        // Parse the first profile object
        const profileObj = userObjects.data[0]
        if (!profileObj.data?.content?.dataType === 'moveObject') {
          return null
        }

        const fields = profileObj.data.content.fields as any
        
        // Return formatted profile
        return {
          id: profileObj.data.objectId,
          owner: fields.owner,
          name: fields.name,
          headline: fields.headline,
          bio: fields.bio,
          profileImageUrl: fields.profile_image_url,
          location: fields.location,
          contactEmail: fields.contact_email,
          experiences: parseVectorField(fields.experiences),
          education: parseVectorField(fields.education),
          skills: parseVectorField(fields.skills),
          connections: parseVectorField(fields.connections),
        }
      } catch (error) {
        console.error('Error fetching user profile:', error)
        return null
      }
    },
    enabled: !!currentAccount?.address && !!packageId,
  })
}

// Helper function to parse vector fields from Sui objects
function parseVectorField(vectorField: any): any[] {
  if (!vectorField || !Array.isArray(vectorField)) {
    return []
  }
  return vectorField
}