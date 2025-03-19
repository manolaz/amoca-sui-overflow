'use client'

import { useCurrentAccount } from '@mysten/dapp-kit'
import {
    Button,
    TextField,
    TextArea,
    Heading,
    Flex,
    Box,
    Card,
    Tabs,
    Text,
    Avatar,
} from '@radix-ui/themes'
import useTransact from '@suiware/kit/useTransact'
import Image from 'next/image'
import { ChangeEvent, FC, MouseEvent, useState } from 'react'
import CustomConnectButton from '~~/components/CustomConnectButton'
import Loading from '~~/components/Loading'
import {
    CONTRACT_PACKAGE_VARIABLE_NAME,
    EXPLORER_URL_VARIABLE_NAME,
} from '~~/config/network'
import { notification } from '~~/helpers/notification'
import useNetworkConfig from '~~/hooks/useNetworkConfig'
import { SuiSignAndExecuteTransactionOutput } from '@mysten/wallet-standard'
import { transactionUrl } from '~~/helpers/network'
import useUserProfile from '../hooks/useUserProfile'
import {
    prepareCreateProfileTransaction,
    prepareUpdateProfileTransaction,
    prepareAddExperienceTransaction,
    prepareAddEducationTransaction,
    prepareAddSkillTransaction,
} from '../helpers/profileTransactions'
import { Profile } from '../hooks/useUserProfile'

const DEFAULT_PROFILE_IMAGE = 'https://placehold.co/400x400?text=Profile+Image'

const ProfileForm: FC = () => {
    const currentAccount = useCurrentAccount()
    const { data: profile, isPending, error, refetch } = useUserProfile()
    const { useNetworkVariable } = useNetworkConfig()
    const packageId = useNetworkVariable(CONTRACT_PACKAGE_VARIABLE_NAME)
    const explorerUrl = useNetworkVariable(EXPLORER_URL_VARIABLE_NAME)

    const [activeTab, setActiveTab] = useState('basic')
    const [notificationId, setNotificationId] = useState<string>()

    // Form state
    const [formData, setFormData] = useState({
        name: '',
        headline: '',
        bio: '',
        profileImageUrl: DEFAULT_PROFILE_IMAGE,
        location: '',
        contactEmail: '',
    })

    // Experience form state
    const [experienceData, setExperienceData] = useState({
        company: '',
        title: '',
        startDate: '',
        endDate: '',
        description: '',
    })

    // Education form state
    const [educationData, setEducationData] = useState({
        institution: '',
        degree: '',
        field: '',
        startDate: '',
        endDate: '',
    })

    // Skill form state
    const [skillName, setSkillName] = useState('')

    // Set form data from profile
    useState(() => {
        if (profile) {
            setFormData({
                name: profile.name,
                headline: profile.headline,
                bio: profile.bio,
                profileImageUrl: profile.profileImageUrl || DEFAULT_PROFILE_IMAGE,
                location: profile.location,
                contactEmail: profile.contactEmail,
            })
        }
    })

    // Transaction hook for creating/updating profile
    const { transact: saveProfile } = useTransact({
        onBeforeStart: () => {
            const nId = notification.txLoading()
            setNotificationId(nId)
        },
        onSuccess: (data: SuiSignAndExecuteTransactionOutput) => {
            notification.txSuccess(
                transactionUrl(explorerUrl, data.digest),
                notificationId
            )
            refetch()
        },
        onError: (e: Error) => {
            notification.txError(e, null, notificationId)
        },
    })

    // Transaction hook for adding experience
    const { transact: addExperience } = useTransact({
        onBeforeStart: () => {
            const nId = notification.txLoading()
            setNotificationId(nId)
        },
        onSuccess: (data: SuiSignAndExecuteTransactionOutput) => {
            notification.txSuccess(
                transactionUrl(explorerUrl, data.digest),
                notificationId
            )
            refetch()
            // Reset form
            setExperienceData({
                company: '',
                title: '',
                startDate: '',
                endDate: '',
                description: '',
            })
        },
        onError: (e: Error) => {
            notification.txError(e, null, notificationId)
        },
    })

    // Transaction hook for adding education
    const { transact: addEducation } = useTransact({
        onBeforeStart: () => {
            const nId = notification.txLoading()
            setNotificationId(nId)
        },
        onSuccess: (data: SuiSignAndExecuteTransactionOutput) => {
            notification.txSuccess(
                transactionUrl(explorerUrl, data.digest),
                notificationId
            )
            refetch()
            // Reset form
            setEducationData({
                institution: '',
                degree: '',
                field: '',
                startDate: '',
                endDate: '',
            })
        },
        onError: (e: Error) => {
            notification.txError(e, null, notificationId)
        },
    })

    // Transaction hook for adding skill
    const { transact: addSkill } = useTransact({
        onBeforeStart: () => {
            const nId = notification.txLoading()
            setNotificationId(nId)
        },
        onSuccess: (data: SuiSignAndExecuteTransactionOutput) => {
            notification.txSuccess(
                transactionUrl(explorerUrl, data.digest),
                notificationId
            )
            refetch()
            // Reset form
            setSkillName('')
        },
        onError: (e: Error) => {
            notification.txError(e, null, notificationId)
        },
    })

    // Handle input changes for basic profile
    const handleInputChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
        const { name, value } = e.target
        setFormData(prev => ({
            ...prev,
            [name]: value,
        }))
    }

    // Handle input changes for experience
    const handleExperienceChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
        const { name, value } = e.target
        setExperienceData(prev => ({
            ...prev,
            [name]: value,
        }))
    }

    // Handle input changes for education
    const handleEducationChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
        const { name, value } = e.target
        setEducationData(prev => ({
            ...prev,
            [name]: value,
        }))
    }

    // Handle profile creation/update
    const handleSaveProfile = async (e: MouseEvent<HTMLButtonElement>) => {
        e.preventDefault()

        if (formData.name.trim() === '') {
            notification.error(null, 'Name is required')
            return
        }

        try {
            // Prepare transaction based on whether we're creating or updating
            const tx = profile?.id
                ? prepareUpdateProfileTransaction(
                    packageId,
                    profile.id,
                    formData.name,
                    formData.headline,
                    formData.bio,
                    formData.profileImageUrl,
                    formData.location,
                    formData.contactEmail
                )
                : prepareCreateProfileTransaction(
                    packageId,
                    formData.name,
                    formData.headline,
                    formData.bio,
                    formData.profileImageUrl,
                    formData.location,
                    formData.contactEmail
                )

            saveProfile(tx)
        } catch (error) {
            console.error('Error saving profile:', error)
            notification.error(null, 'Failed to save profile')
        }
    }

    // Handle adding experience
    const handleAddExperience = async (e: MouseEvent<HTMLButtonElement>) => {
        e.preventDefault()

        if (!profile?.id || !experienceData.company || !experienceData.title) {
            notification.error(null, 'Company and Title are required')
            return
        }

        try {
            const tx = prepareAddExperienceTransaction(
                packageId,
                profile.id,
                experienceData.company,
                experienceData.title,
                experienceData.startDate,
                experienceData.endDate,
                experienceData.description
            )

            addExperience(tx)
        } catch (error) {
            console.error('Error adding experience:', error)
            notification.error(null, 'Failed to add experience')
        }
    }

    // Handle adding education
    const handleAddEducation = async (e: MouseEvent<HTMLButtonElement>) => {
        e.preventDefault()

        if (!profile?.id || !educationData.institution || !educationData.degree) {
            notification.error(null, 'Institution and Degree are required')
            return
        }

        try {
            const tx = prepareAddEducationTransaction(
                packageId,
                profile.id,
                educationData.institution,
                educationData.degree,
                educationData.field,
                educationData.startDate,
                educationData.endDate
            )

            addEducation(tx)
        } catch (error) {
            console.error('Error adding education:', error)
            notification.error(null, 'Failed to add education')
        }
    }

    // Handle adding skill
    const handleAddSkill = async (e: MouseEvent<HTMLButtonElement>) => {
        e.preventDefault()

        if (!profile?.id || !skillName) {
            notification.error(null, 'Skill name is required')
            return
        }

        try {
            const tx = prepareAddSkillTransaction(
                packageId,
                profile.id,
                skillName
            )

            addSkill(tx)
        } catch (error) {
            console.error('Error adding skill:', error)
            notification.error(null, 'Failed to add skill')
        }
    }

    if (!currentAccount) return <CustomConnectButton />

    if (isPending) return <Loading />

    if (error) return <div>Error: {error.message}</div>

    return (
        <div className="w-full max-w-4xl mx-auto">
            <Heading size="8" className="text-center mb-8">
                {profile ? 'Edit Your Profile' : 'Create Your AMOCA Profile'}
            </Heading>

            {profile && (
                <Box className="mb-8">
                    <Card className="p-6">
                        <Flex align="center" gap="4">
                            <Avatar
                                size="6"
                                src={profile.profileImageUrl || DEFAULT_PROFILE_IMAGE}
                                fallback={profile.name.charAt(0)}
                                radius="full"
                            />
                            <Box>
                                <Heading size="6">{profile.name}</Heading>
                                <Text size="3" className="text-gray-500">{profile.headline}</Text>
                                <Text size="2" className="text-gray-400">{profile.location}</Text>
                            </Box>
                        </Flex>
                    </Card>
                </Box>
            )}

            <Tabs.Root value={activeTab} onValueChange={setActiveTab}>
                <Tabs.List className="mb-6">
                    <Tabs.Trigger value="basic">Basic Info</Tabs.Trigger>
                    <Tabs.Trigger value="experience" disabled={!profile}>Experience</Tabs.Trigger>
                    <Tabs.Trigger value="education" disabled={!profile}>Education</Tabs.Trigger>
                    <Tabs.Trigger value="skills" disabled={!profile}>Skills</Tabs.Trigger>
                </Tabs.List>

                <Tabs.Content value="basic">
                    <Card className="p-6">
                        <Flex direction="column" gap="4">
                            <TextField.Root>
                                <TextField.Label>Full Name*</TextField.Label>
                                <TextField.Input
                                    name="name"
                                    value={formData.name}
                                    onChange={handleInputChange}
                                    placeholder="e.g. John Doe"
                                    required
                                />
                            </TextField.Root>

                            <TextField.Root>
                                <TextField.Label>Professional Headline</TextField.Label>
                                <TextField.Input
                                    name="headline"
                                    value={formData.headline}
                                    onChange={handleInputChange}
                                    placeholder="e.g. Software Engineer at AMOCA"
                                />
                            </TextField.Root>

                            <Box>
                                <TextArea
                                    name="bio"
                                    value={formData.bio}
                                    onChange={handleInputChange}
                                    placeholder="Enter your professional bio..."
                                    rows={5}
                                />
                            </Box>

                            <TextField.Root>
                                <TextField.Label>Profile Image URL</TextField.Label>
                                <TextField.Input
                                    name="profileImageUrl"
                                    value={formData.profileImageUrl}
                                    onChange={handleInputChange}
                                    placeholder="https://..."
                                />
                            </TextField.Root>

                            <TextField.Root>
                                <TextField.Label>Location</TextField.Label>
                                <TextField.Input
                                    name="location"
                                    value={formData.location}
                                    onChange={handleInputChange}
                                    placeholder="e.g. San Francisco, CA"
                                />
                            </TextField.Root>

                            <TextField.Root>
                                <TextField.Label>Contact Email</TextField.Label>
                                <TextField.Input
                                    name="contactEmail"
                                    value={formData.contactEmail}
                                    onChange={handleInputChange}
                                    placeholder="your@email.com"
                                />
                            </TextField.Root>

                            <Button
                                size="3"
                                onClick={handleSaveProfile}
                            >
                                {profile ? 'Update Profile' : 'Create Profile'}
                            </Button>
                        </Flex>
                    </Card>
                </Tabs.Content>

                <Tabs.Content value="experience">
                    <Card className="p-6 mb-6">
                        <Heading size="4" className="mb-4">Add Work Experience</Heading>
                        <Flex direction="column" gap="4">
                            <TextField.Root>
                                <TextField.Label>Company*</TextField.Label>
                                <TextField.Input
                                    name="company"
                                    value={experienceData.company}
                                    onChange={handleExperienceChange}
                                    placeholder="e.g. AMOCA Network"
                                    required
                                />
                            </TextField.Root>

                            <TextField.Root>
                                <TextField.Label>Title*</TextField.Label>
                                <TextField.Input
                                    name="title"
                                    value={experienceData.title}
                                    onChange={handleExperienceChange}
                                    placeholder="e.g. Senior Developer"
                                    required
                                />
                            </TextField.Root>

                            <Flex gap="4">
                                <TextField.Root className="flex-1">
                                    <TextField.Label>Start Date</TextField.Label>
                                    <TextField.Input
                                        name="startDate"
                                        value={experienceData.startDate}
                                        onChange={handleExperienceChange}
                                        placeholder="e.g. Jan 2020"
                                    />
                                </TextField.Root>

                                <TextField.Root className="flex-1">
                                    <TextField.Label>End Date</TextField.Label>
                                    <TextField.Input
                                        name="endDate"
                                        value={experienceData.endDate}
                                        onChange={handleExperienceChange}
                                        placeholder="e.g. Present"
                                    />
                                </TextField.Root>
                            </Flex>

                            <Box>
                                <TextArea
                                    name="description"
                                    value={experienceData.description}
                                    onChange={handleExperienceChange}
                                    placeholder="Describe your role and responsibilities..."
                                    rows={3}
                                />
                            </Box>

                            <Button
                                size="3"
                                onClick={handleAddExperience}
                            >
                                Add Experience
                            </Button>
                        </Flex>
                    </Card>

                    {profile && profile.experiences.length > 0 && (
                        <Box>
                            <Heading size="4" className="mb-4">Your Experiences</Heading>
                            {profile.experiences.map((exp, index) => (
                                <Card key={index} className="p-4 mb-4">
                                    <Heading size="5">{exp.title}</Heading>
                                    <Text size="3">{exp.company}</Text>
                                    <Text size="2" className="text-gray-500">
                                        {exp.startDate} - {exp.endDate}
                                    </Text>
                                    <Text size="2" className="mt-2">{exp.description}</Text>
                                </Card>
                            ))}
                        </Box>
                    )}
                </Tabs.Content>

                <Tabs.Content value="education">
                    <Card className="p-6 mb-6">
                        <Heading size="4" className="mb-4">Add Education</Heading>
                        <Flex direction="column" gap="4">
                            <TextField.Root>
                                <TextField.Label>Institution*</TextField.Label>
                                <TextField.Input
                                    name="institution"
                                    value={educationData.institution}
                                    onChange={handleEducationChange}
                                    placeholder="e.g. Stanford University"
                                    required
                                />
                            </TextField.Root>

                            <TextField.Root>
                                <TextField.Label>Degree*</TextField.Label>
                                <TextField.Input
                                    name="degree"
                                    value={educationData.degree}
                                    onChange={handleEducationChange}
                                    placeholder="e.g. Bachelor's"
                                    required
                                />
                            </TextField.Root>

                            <TextField.Root>
                                <TextField.Label>Field of Study</TextField.Label>
                                <TextField.Input
                                    name="field"
                                    value={educationData.field}
                                    onChange={handleEducationChange}
                                    placeholder="e.g. Computer Science"
                                />
                            </TextField.Root>

                            <Flex gap="4">
                                <TextField.Root className="flex-1">
                                    <TextField.Label>Start Date</TextField.Label>
                                    <TextField.Input
                                        name="startDate"
                                        value={educationData.startDate}
                                        onChange={handleEducationChange}
                                        placeholder="e.g. 2015"
                                    />
                                </TextField.Root>

                                <TextField.Root className="flex-1">
                                    <TextField.Label>End Date</TextField.Label>
                                    <TextField.Input
                                        name="endDate"
                                        value={educationData.endDate}
                                        onChange={handleEducationChange}
                                        placeholder="e.g. 2019"
                                    />
                                </TextField.Root>
                            </Flex>

                            <Button
                                size="3"
                                onClick={handleAddEducation}
                            >
                                Add Education
                            </Button>
                        </Flex>
                    </Card>

                    {profile && profile.education.length > 0 && (
                        <Box>
                            <Heading size="4" className="mb-4">Your Education</Heading>
                            {profile.education.map((edu, index) => (
                                <Card key={index} className="p-4 mb-4">
                                    <Heading size="5">{edu.degree} in {edu.field}</Heading>
                                    <Text size="3">{edu.institution}</Text>
                                    <Text size="2" className="text-gray-500">
                                        {edu.startDate} - {edu.endDate}
                                    </Text>
                                </Card>
                            ))}
                        </Box>
                    )}
                </Tabs.Content>

                <Tabs.Content value="skills">
                    <Card className="p-6 mb-6">
                        <Heading size="4" className="mb-4">Add Skills</Heading>
                        <Flex gap="4">
                            <TextField.Root className="flex-1">
                                <TextField.Label>Skill Name*</TextField.Label>
                                <TextField.Input
                                    value={skillName}
                                    onChange={(e) => setSkillName(e.target.value)}
                                    placeholder="e.g. React, JavaScript, Sui Move"
                                    required
                                />
                            </TextField.Root>

                            <Button
                                size="3"
                                onClick={handleAddSkill}
                            >
                                Add Skill
                            </Button>
                        </Flex>
                    </Card>

                    {profile && profile.skills.length > 0 && (
                        <Box>
                            <Heading size="4" className="mb-4">Your Skills</Heading>
                            <Flex gap="2" wrap="wrap">
                                {profile.skills.map((skill, index) => (
                                    <Card key={index} className="p-2 mb-2">
                                        <Flex gap="2" align="center">
                                            <Text>{skill.name}</Text>
                                            {skill.endorsements > 0 && (
                                                <Text size="1" className="text-gray-500">
                                                    {skill.endorsements} endorsements
                                                </Text>
                                            )}
                                        </Flex>
                                    </Card>
                                ))}
                            </Flex>
                        </Box>
                    )}
                </Tabs.Content>
            </Tabs.Root>
        </div>
    )
}

export default ProfileForm