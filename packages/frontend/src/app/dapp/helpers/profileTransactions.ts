import { TransactionBlock } from '@mysten/sui.js/transactions'

/**
 * Prepares a transaction to create a user profile
 * @param packageId The package ID of the AMOCA contract
 * @param name User's full name
 * @param headline Professional headline
 * @param bio User's biography/about section
 * @param profileImageUrl URL to the profile image
 * @param location User's location
 * @param contactEmail User's contact email
 * @returns The prepared transaction
 */
export function prepareCreateProfileTransaction(
  packageId: string,
  name: string,
  headline: string,
  bio: string,
  profileImageUrl: string,
  location: string,
  contactEmail: string
) {
  const tx = new TransactionBlock()
  tx.moveCall({
    target: `${packageId}::profile::create_profile`,
    arguments: [
      tx.pure(name),
      tx.pure(headline),
      tx.pure(bio),
      tx.pure(profileImageUrl),
      tx.pure(location),
      tx.pure(contactEmail),
    ],
  })
  return tx
}

/**
 * Prepares a transaction to update a user profile
 * @param packageId The package ID of the AMOCA contract
 * @param profileId The ID of the profile to update
 * @param name User's full name
 * @param headline Professional headline
 * @param bio User's biography/about section
 * @param profileImageUrl URL to the profile image
 * @param location User's location
 * @param contactEmail User's contact email
 * @returns The prepared transaction
 */
export function prepareUpdateProfileTransaction(
  packageId: string,
  profileId: string,
  name: string,
  headline: string,
  bio: string,
  profileImageUrl: string,
  location: string,
  contactEmail: string
) {
  const tx = new TransactionBlock()
  tx.moveCall({
    target: `${packageId}::profile::update_profile_info`,
    arguments: [
      tx.object(profileId),
      tx.pure(name),
      tx.pure(headline),
      tx.pure(bio),
      tx.pure(profileImageUrl),
      tx.pure(location),
      tx.pure(contactEmail),
    ],
  })
  return tx
}

/**
 * Prepares a transaction to add work experience to a profile
 * @param packageId The package ID of the AMOCA contract
 * @param profileId The ID of the profile
 * @param company Company name
 * @param title Job title
 * @param startDate Start date
 * @param endDate End date (or "Present")
 * @param description Job description
 * @returns The prepared transaction
 */
export function prepareAddExperienceTransaction(
  packageId: string,
  profileId: string,
  company: string,
  title: string,
  startDate: string,
  endDate: string,
  description: string
) {
  const tx = new TransactionBlock()
  tx.moveCall({
    target: `${packageId}::profile::add_experience`,
    arguments: [
      tx.object(profileId),
      tx.pure(company),
      tx.pure(title),
      tx.pure(startDate),
      tx.pure(endDate),
      tx.pure(description),
    ],
  })
  return tx
}

/**
 * Prepares a transaction to add education to a profile
 * @param packageId The package ID of the AMOCA contract
 * @param profileId The ID of the profile
 * @param institution Educational institution name
 * @param degree Degree type
 * @param field Field of study
 * @param startDate Start date
 * @param endDate End date (or "Present")
 * @returns The prepared transaction
 */
export function prepareAddEducationTransaction(
  packageId: string,
  profileId: string,
  institution: string,
  degree: string,
  field: string,
  startDate: string,
  endDate: string
) {
  const tx = new TransactionBlock()
  tx.moveCall({
    target: `${packageId}::profile::add_education`,
    arguments: [
      tx.object(profileId),
      tx.pure(institution),
      tx.pure(degree),
      tx.pure(field),
      tx.pure(startDate),
      tx.pure(endDate),
    ],
  })
  return tx
}

/**
 * Prepares a transaction to add a skill to a profile
 * @param packageId The package ID of the AMOCA contract
 * @param profileId The ID of the profile
 * @param skillName Name of the skill
 * @returns The prepared transaction
 */
export function prepareAddSkillTransaction(
  packageId: string,
  profileId: string,
  skillName: string
) {
  const tx = new TransactionBlock()
  tx.moveCall({
    target: `${packageId}::profile::add_skill`,
    arguments: [
      tx.object(profileId),
      tx.pure(skillName),
    ],
  })
  return tx
}

/**
 * Prepares a transaction to add a connection to a profile
 * @param packageId The package ID of the AMOCA contract
 * @param profileId The ID of the profile
 * @param connectionAddress Address of the user to connect with
 * @returns The prepared transaction
 */
export function prepareAddConnectionTransaction(
  packageId: string,
  profileId: string,
  connectionAddress: string
) {
  const tx = new TransactionBlock()
  tx.moveCall({
    target: `${packageId}::profile::add_connection`,
    arguments: [
      tx.object(profileId),
      tx.pure(connectionAddress),
    ],
  })
  return tx
}