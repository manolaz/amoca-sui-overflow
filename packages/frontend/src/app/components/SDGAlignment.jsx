import React from "react";
import {
  Box,
  Heading,
  Text,
  SimpleGrid,
  VStack,
  Image,
  useColorModeValue,
} from "@chakra-ui/react";

const SDGCard = ({ number, title, description, imageUrl }) => {
  const bgColor = useColorModeValue("white", "gray.800");
  const borderColor = useColorModeValue("gray.200", "gray.700");

  return (
    <Box
      p={5}
      shadow="md"
      borderWidth="1px"
      borderRadius="lg"
      bg={bgColor}
      borderColor={borderColor}
    >
      <VStack spacing={3} align="start">
        <Box display="flex" alignItems="center">
          {imageUrl && (
            <Image src={imageUrl} alt={`SDG ${number}`} boxSize="50px" mr={3} />
          )}
          <Heading size="md">
            SDG {number}: {title}
          </Heading>
        </Box>
        <Text>{description}</Text>
      </VStack>
    </Box>
  );
};

const SDGAlignment = () => {
  const sdgs = [
    {
      number: 13,
      title: "Climate Action",
      description:
        "AMOCA's core mission directly aligns with taking urgent action to combat climate change and its impacts. Our platform revolutionizes climate finance and accelerates global sustainability by supporting climate initiatives through innovative funding mechanisms.",
      imageUrl: "/images/sdg-13.png", // You'll need to add these images
    },
    {
      number: 17,
      title: "Partnerships for the Goals",
      description:
        "AMOCA emphasizes uniting governments, international organizations, private investors, and climate innovators in a decentralized alliance. This collaborative approach across different sectors is central to achieving sustainable development globally.",
      imageUrl: "/images/sdg-17.png",
    },
    {
      number: 7,
      title: "Affordable and Clean Energy",
      description:
        "AMOCA supports renewable energy projects through our platform, contributing directly to the goal of ensuring access to affordable, reliable, sustainable, and modern energy for all.",
      imageUrl: "/images/sdg-7.png",
    },
    {
      number: 9,
      title: "Industry, Innovation and Infrastructure",
      description:
        "By leveraging blockchain technology (Sui ecosystem) and advanced modeling for climate initiatives, AMOCA promotes innovation and contributes to building resilient infrastructure for climate action.",
      imageUrl: "/images/sdg-9.png",
    },
  ];

  return (
    <Box py={8}>
      <Heading as="h2" size="xl" mb={6} textAlign="center">
        Supporting UN Sustainable Development Goals
      </Heading>
      <Text mb={8} textAlign="center">
        AMOCA's work is aligned with and actively contributes to the following
        United Nations Sustainable Development Goals:
      </Text>
      <SimpleGrid columns={{ base: 1, md: 2 }} spacing={10}>
        {sdgs.map((sdg) => (
          <SDGCard key={sdg.number} {...sdg} />
        ))}
      </SimpleGrid>
    </Box>
  );
};

export default SDGAlignment;
